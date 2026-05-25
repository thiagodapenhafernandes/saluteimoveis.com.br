class Admin::ImageMigrationStatusController < Admin::BaseController
  before_action -> { check_permission!(:manage, :integracoes) }

  PUBLIC_STATUSES = ["Venda", "Aluguel"].freeze
  CONFIG_PREFIX = "image_migration.".freeze
  SYNC_MODES = {
    "missing_properties" => "Apenas imóveis sem fotos anexadas",
    "cursor" => "Continuar do último cursor",
    "full_scan" => "Varrer desde o início, sem filtrar por anexo"
  }.freeze
  DEFAULT_CONFIGURATION = {
    "mode" => "missing_properties",
    "batch_size" => "100",
    "loop" => "true",
    "sleep_seconds" => "2",
    "max_cycles" => "0",
    "start_id" => "0",
    "max_id" => "0",
    "skip_analysis" => "true",
    "dry_run" => "false"
  }.freeze

  def index
    @status = build_status
    @configuration = image_migration_configuration

    respond_to do |format|
      format.html
      format.json { render json: @status }
    end
  end

  def update_configuration
    config = normalized_configuration(configuration_params)

    config.each do |key, value|
      Setting.set("#{CONFIG_PREFIX}#{key}", value, image_migration_setting_description(key))
    end

    redirect_to admin_image_migration_status_path, notice: "Configurações da migração de imagens salvas."
  rescue => e
    redirect_to admin_image_migration_status_path, alert: "Erro ao salvar configurações: #{e.message}"
  end

  def sync
    if worker_status[:running]
      redirect_to admin_image_migration_status_path, alert: "A migração de imagens já está rodando."
      return
    end

    configuration = image_migration_configuration
    start_images_sync!(configuration)

    redirect_to admin_image_migration_status_path, notice: "Migração de imagens iniciada em segundo plano com as configurações salvas."
  rescue => e
    redirect_to admin_image_migration_status_path, alert: "Falha ao iniciar migração de imagens: #{e.message}"
  end

  def retry_failed
    if worker_status[:running]
      redirect_to admin_image_migration_status_path, alert: "A migração de imagens já está rodando."
      return
    end

    start_failed_retry!

    redirect_to admin_image_migration_status_path, notice: "Retry dos imóveis com falha iniciado em segundo plano."
  rescue => e
    redirect_to admin_image_migration_status_path, alert: "Falha ao iniciar retry: #{e.message}"
  end

  private

  def build_status
    source_scope = Habitation
      .where.not(imovel_dwv: "Sim")
      .where("jsonb_typeof(pictures) = ? AND jsonb_array_length(pictures) > 0", "array")

    total_properties = source_scope.count
    properties_with_photos = source_scope.joins(:photos_attachments).distinct.count
    pending_properties = source_scope.where.missing(:photos_attachments).count
    public_pending_properties = source_scope.where(status: PUBLIC_STATUSES).where.missing(:photos_attachments).count
    public_vista_first_properties = public_vista_first_scope.count
    total_source_images = source_scope.pick(Arel.sql("COALESCE(SUM(jsonb_array_length(pictures)), 0)::bigint")).to_i
    migrated_images = ActiveStorage::Attachment.where(record_type: "Habitation", name: "photos").count
    latest_attachment_at = ActiveStorage::Attachment.where(record_type: "Habitation", name: "photos").maximum(:created_at)
    failed_ids = failed_habitation_ids
    cursor_data = current_cursor_data
    worker = worker_status

    {
      total_properties: total_properties,
      properties_with_photos: properties_with_photos,
      pending_properties: pending_properties,
      public_pending_properties: public_pending_properties,
      public_vista_first_properties: public_vista_first_properties,
      public_vista_first_sample: public_vista_first_scope.limit(20).pluck(:id),
      property_progress: percentage(properties_with_photos, total_properties),
      total_source_images: total_source_images,
      migrated_images: migrated_images,
      image_progress: percentage([migrated_images, total_source_images].min, total_source_images),
      failed_properties: failed_ids.size,
      failed_sample: failed_ids.first(20),
      cursor_last_id: cursor_data["last_id"].to_i.presence,
      worker: worker,
      latest_attachment_at: latest_attachment_at,
      execution: execution_status(
        worker: worker,
        cursor_data: cursor_data,
        source_scope: source_scope,
        pending_properties: pending_properties,
        properties_with_photos: properties_with_photos,
        migrated_images: migrated_images
      ),
      paths: {
        cursor: cursor_file.to_s,
        failed: failed_file.to_s,
        log: log_file.to_s
      }
    }
  end

  def percentage(current, total)
    return 100.0 if total.to_i.zero?

    ((current.to_f / total.to_f) * 100).round(2)
  end

  def public_vista_first_scope
    Habitation
      .where.not(imovel_dwv: "Sim")
      .where(exibir_no_site_flag: true)
      .where(status: PUBLIC_STATUSES)
      .where("jsonb_typeof(pictures) = ? AND jsonb_array_length(pictures) > 0", "array")
      .where.missing(:photos_attachments)
  end

  def worker_status
    pid = read_integer(pid_file)
    running = pid.present? && process_running?(pid)

    {
      running: running,
      pid: pid,
      status: running ? "Rodando" : "Parado"
    }
  end

  def process_running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  rescue
    false
  end

  def failed_habitation_ids
    return [] unless failed_file.exist?

    failed_file.readlines(chomp: true).map(&:to_i).select(&:positive?).uniq
  rescue
    []
  end

  def cursor_last_id
    read_integer(cursor_file, /^last_id:\s*(\d+)/)
  end

  def current_cursor_data
    return {} unless cursor_file.exist?

    content = cursor_file.read
    YAML.safe_load(
      content,
      permitted_classes: [Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone],
      aliases: true
    ) || {}
  rescue
    {
      "last_id" => read_integer(cursor_file, /^last_id:\s*(\d+)/),
      "cycle" => read_integer(cursor_file, /^cycle:\s*(\d+)/),
      "synced" => read_integer(cursor_file, /^synced:\s*(\d+)/),
      "skipped" => read_integer(cursor_file, /^skipped:\s*(\d+)/),
      "failed" => read_integer(cursor_file, /^failed:\s*(\d+)/)
    }.compact
  end

  def read_integer(path, pattern = /\A\s*(\d+)\s*\z/)
    return nil unless path.exist?

    content = path.read
    match = content.match(pattern)
    match ? match[1].to_i : nil
  rescue
    nil
  end

  def start_images_sync!(configuration)
    FileUtils.mkdir_p(shared_tmp)
    FileUtils.mkdir_p(shared_log)
    record_run_start!(configuration)

    env = {
      "RAILS_ENV" => Rails.env,
      "BATCH_SIZE" => configuration.fetch("batch_size"),
      "ONLY_WITHOUT_ATTACHMENTS" => only_without_attachments_for(configuration.fetch("mode")),
      "RESET_CURSOR" => reset_cursor_for(configuration.fetch("mode")),
      "LOOP" => configuration.fetch("loop"),
      "STOP_WHEN_DONE" => "true",
      "SLEEP_SECONDS" => configuration.fetch("sleep_seconds"),
      "MAX_CYCLES" => configuration.fetch("max_cycles"),
      "START_ID" => configuration.fetch("start_id"),
      "MAX_ID" => configuration.fetch("max_id"),
      "SKIP_ANALYSIS" => configuration.fetch("skip_analysis"),
      "DRY_RUN" => configuration.fetch("dry_run"),
      "CURSOR_FILE" => cursor_file.to_s,
      "FAILED_FILE" => failed_file.to_s
    }

    spawn_rake!(env, "images:sync_habitations_to_spaces")
  end

  def start_failed_retry!
    FileUtils.mkdir_p(shared_tmp)
    FileUtils.mkdir_p(shared_log)

    configuration = image_migration_configuration
    record_run_start!(configuration.merge("mode" => "retry_failed"))
    env = {
      "RAILS_ENV" => Rails.env,
      "SKIP_ANALYSIS" => configuration.fetch("skip_analysis"),
      "DRY_RUN" => configuration.fetch("dry_run"),
      "FAILED_FILE" => failed_file.to_s
    }

    spawn_rake!(env, "images:retry_failed_habitations_to_spaces")
  end

  def spawn_rake!(env, task_name)
    pid = Process.spawn(env, Gem.ruby, "-S", "bundle", "exec", "rake", task_name,
      chdir: Rails.root.to_s,
      out: [log_file.to_s, "a"],
      err: [:child, :out],
      pgroup: true)

    pid_file.write(pid.to_s)
    Process.detach(pid)
  end

  def record_run_start!(configuration)
    status = build_status_for_run_start
    values = {
      "mode" => configuration.fetch("mode"),
      "started_at" => Time.current.iso8601,
      "initial_pending_properties" => status.fetch(:pending_properties).to_s,
      "initial_properties_with_photos" => status.fetch(:properties_with_photos).to_s,
      "initial_migrated_images" => status.fetch(:migrated_images).to_s,
      "initial_cursor_last_id" => status.fetch(:cursor_last_id).to_i.to_s,
      "configured_start_id" => configuration.fetch("start_id", "0").to_s,
      "configured_max_id" => configuration.fetch("max_id", "0").to_s
    }

    values.each do |key, value|
      Setting.set("#{CONFIG_PREFIX}run.#{key}", value, "Estado da execução atual da migração de imagens")
    end
  end

  def build_status_for_run_start
    source_scope = Habitation
      .where.not(imovel_dwv: "Sim")
      .where("jsonb_typeof(pictures) = ? AND jsonb_array_length(pictures) > 0", "array")

    {
      pending_properties: source_scope.where.missing(:photos_attachments).count,
      properties_with_photos: source_scope.joins(:photos_attachments).distinct.count,
      migrated_images: ActiveStorage::Attachment.where(record_type: "Habitation", name: "photos").count,
      cursor_last_id: cursor_last_id
    }
  end

  def execution_status(worker:, cursor_data:, source_scope:, pending_properties:, properties_with_photos:, migrated_images:)
    mode = Setting.get("#{CONFIG_PREFIX}run.mode", image_migration_configuration.fetch("mode"))
    started_at = Setting.get("#{CONFIG_PREFIX}run.started_at")
    initial_pending = Setting.get("#{CONFIG_PREFIX}run.initial_pending_properties", pending_properties.to_s).to_i
    initial_properties_with_photos = Setting.get("#{CONFIG_PREFIX}run.initial_properties_with_photos", properties_with_photos.to_s).to_i
    initial_migrated_images = Setting.get("#{CONFIG_PREFIX}run.initial_migrated_images", migrated_images.to_s).to_i
    initial_cursor_last_id = Setting.get("#{CONFIG_PREFIX}run.initial_cursor_last_id", "0").to_i
    configured_start_id = Setting.get("#{CONFIG_PREFIX}run.configured_start_id", "0").to_i
    configured_max_id = Setting.get("#{CONFIG_PREFIX}run.configured_max_id", "0").to_i
    cursor_last_id = cursor_data["last_id"].to_i

    progress_payload = if mode == "missing_properties" && initial_pending.positive?
      current = (initial_pending - pending_properties).clamp(0, initial_pending)
      {
        label: "Imóveis faltantes migrados nesta execução",
        current: current,
        total: initial_pending,
        remaining: pending_properties,
        progress: percentage(current, initial_pending)
      }
    elsif mode == "retry_failed"
      failed_total = failed_habitation_ids.size
      failed_current = cursor_data["failed"].to_i
      synced_current = cursor_data["synced"].to_i
      current = synced_current + failed_current
      total = [failed_total, current].max
      {
        label: "Retry de imóveis com falha",
        current: current,
        total: total,
        remaining: [failed_total - current, 0].max,
        progress: percentage(current, total)
      }
    else
      max_source_id = configured_max_id.positive? ? configured_max_id : source_scope.maximum(:id).to_i
      start_id = configured_start_id.positive? ? configured_start_id - 1 : initial_cursor_last_id
      total = [max_source_id - start_id, 0].max
      current = (cursor_last_id - start_id).clamp(0, total)
      {
        label: "Varredura por ID",
        current: current,
        total: total,
        remaining: [total - current, 0].max,
        progress: percentage(current, total)
      }
    end

    {
      mode: mode,
      running: worker[:running],
      started_at: started_at,
      last_run_at: cursor_data["last_run_at"],
      cycle: cursor_data["cycle"].to_i,
      cursor_last_id: cursor_last_id,
      synced: cursor_data["synced"].to_i,
      skipped: cursor_data["skipped"].to_i,
      failed: cursor_data["failed"].to_i,
      properties_added: [properties_with_photos - initial_properties_with_photos, 0].max,
      images_added: [migrated_images - initial_migrated_images, 0].max
    }.merge(progress_payload)
  end

  def image_migration_configuration
    DEFAULT_CONFIGURATION.each_with_object({}) do |(key, default_value), configuration|
      configuration[key] = Setting.get("#{CONFIG_PREFIX}#{key}", default_value).to_s
    end
  end

  def normalized_configuration(raw_params)
    {
      "mode" => SYNC_MODES.key?(raw_params[:mode]) ? raw_params[:mode] : DEFAULT_CONFIGURATION.fetch("mode"),
      "batch_size" => clamp_integer(raw_params[:batch_size], 1, 500, DEFAULT_CONFIGURATION.fetch("batch_size")),
      "loop" => boolean_string(raw_params[:loop]),
      "sleep_seconds" => clamp_decimal(raw_params[:sleep_seconds], 0.5, 30.0, DEFAULT_CONFIGURATION.fetch("sleep_seconds")),
      "max_cycles" => clamp_integer(raw_params[:max_cycles], 0, 10_000, DEFAULT_CONFIGURATION.fetch("max_cycles")),
      "start_id" => clamp_integer(raw_params[:start_id], 0, 2_147_483_647, DEFAULT_CONFIGURATION.fetch("start_id")),
      "max_id" => clamp_integer(raw_params[:max_id], 0, 2_147_483_647, DEFAULT_CONFIGURATION.fetch("max_id")),
      "skip_analysis" => boolean_string(raw_params[:skip_analysis]),
      "dry_run" => boolean_string(raw_params[:dry_run])
    }
  end

  def clamp_integer(value, min, max, default)
    integer = Integer(value.to_s, exception: false)
    integer = default.to_i if integer.nil?
    integer.clamp(min, max).to_s
  end

  def clamp_decimal(value, min, max, default)
    decimal = Float(value.to_s, exception: false)
    decimal = default.to_f if decimal.nil?
    decimal.clamp(min, max).to_s
  end

  def boolean_string(value)
    ActiveModel::Type::Boolean.new.cast(value).to_s
  end

  def only_without_attachments_for(mode)
    (mode == "missing_properties").to_s
  end

  def reset_cursor_for(mode)
    %w[missing_properties full_scan].include?(mode).to_s
  end

  def image_migration_setting_description(key)
    {
      "mode" => "Modo de execução da migração de imagens",
      "batch_size" => "Quantidade de imóveis por lote da migração de imagens",
      "loop" => "Continua processando ciclos até acabar o escopo",
      "sleep_seconds" => "Pausa entre ciclos da migração de imagens",
      "max_cycles" => "Limite máximo de ciclos da migração de imagens",
      "start_id" => "ID inicial opcional da migração de imagens",
      "max_id" => "ID final opcional da migração de imagens",
      "skip_analysis" => "Marca blobs como analisados para evitar AnalyzeJob",
      "dry_run" => "Simula a migração de imagens sem anexar arquivos"
    }[key]
  end

  def configuration_params
    params.require(:image_migration).permit(
      :mode,
      :batch_size,
      :loop,
      :sleep_seconds,
      :max_cycles,
      :start_id,
      :max_id,
      :skip_analysis,
      :dry_run
    )
  end

  def pid_file
    shared_tmp.join("spaces_images_sync.pid")
  end

  def cursor_file
    shared_tmp.join("spaces_habitation_images_cursor.yml")
  end

  def failed_file
    shared_tmp.join("spaces_habitation_images_failed_ids.log")
  end

  def log_file
    shared_log.join("spaces_images_sync.log")
  end

  def shared_tmp
    configured_shared_path("SPACES_IMAGE_SYNC_SHARED_TMP", "/home/salute/deploy/shared/tmp", Rails.root.join("tmp"))
  end

  def shared_log
    configured_shared_path("SPACES_IMAGE_SYNC_SHARED_LOG", "/home/salute/deploy/shared/log", Rails.root.join("log"))
  end

  def configured_shared_path(env_key, production_path, fallback_path)
    configured = ENV[env_key].presence
    return Pathname.new(configured) if configured

    production = Pathname.new(production_path)
    production.exist? ? production : Pathname.new(fallback_path)
  end
end

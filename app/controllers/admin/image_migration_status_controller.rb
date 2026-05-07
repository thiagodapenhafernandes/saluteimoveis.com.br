class Admin::ImageMigrationStatusController < Admin::BaseController
  before_action -> { check_permission!(:manage, :integracoes) }

  PUBLIC_STATUSES = ["Venda", "Aluguel"].freeze

  def index
    @status = build_status

    respond_to do |format|
      format.html
      format.json { render json: @status }
    end
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
    total_source_images = source_scope.pick(Arel.sql("COALESCE(SUM(jsonb_array_length(pictures)), 0)::bigint")).to_i
    migrated_images = ActiveStorage::Attachment.where(record_type: "Habitation", name: "photos").count
    latest_attachment_at = ActiveStorage::Attachment.where(record_type: "Habitation", name: "photos").maximum(:created_at)
    failed_ids = failed_habitation_ids

    {
      total_properties: total_properties,
      properties_with_photos: properties_with_photos,
      pending_properties: pending_properties,
      public_pending_properties: public_pending_properties,
      property_progress: percentage(properties_with_photos, total_properties),
      total_source_images: total_source_images,
      migrated_images: migrated_images,
      image_progress: percentage([migrated_images, total_source_images].min, total_source_images),
      failed_properties: failed_ids.size,
      failed_sample: failed_ids.first(20),
      cursor_last_id: cursor_last_id,
      worker: worker_status,
      latest_attachment_at: latest_attachment_at,
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

  def read_integer(path, pattern = /\A\s*(\d+)\s*\z/)
    return nil unless path.exist?

    content = path.read
    match = content.match(pattern)
    match ? match[1].to_i : nil
  rescue
    nil
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

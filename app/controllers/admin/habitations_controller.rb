class Admin::HabitationsController < Admin::BaseController
  before_action -> { check_permission!(:view, :imoveis) }
  before_action :require_admin!, only: [:bulk_publish, :bulk_publish_eligibility]
  before_action :scope_habitations_by_permission, only: [:edit, :update, :destroy, :sync, :purge_attachment]
  require "csv"

  REPORT_TYPES = {
    "photos_sheet" => "Ficha de fotos",
    "client_sheet_commercial" => "Ficha para clientes - Imoveis comerciais",
    "client_sheet_residential" => "Ficha para clientes - Imoveis residenciais",
    "client_sheet_land" => "Ficha para clientes - Terrenos",
    "vitrine_sheet" => "Ficha vitrine",
    "sale_rent_total_values" => "Ficha Imoveis com valor geral de venda e aluguel",
    "property_list" => "Ficha Listagem de imoveis",
    "property_list_with_m2" => "Ficha Listagem de imoveis com Valor do M2",
    "property_list_by_broker" => "Ficha Listagem de imoveis por corretor",
    "property_count_by_broker" => "Ficha Numero de imoveis por corretor"
  }.freeze
  REPORT_PAGE_SIZE = {
    "property_list" => 24,
    "property_list_with_m2" => 24,
    "property_list_by_broker" => 14
  }.freeze
  REPORT_MAX_PAGES = 100
  AMENITY_FILTER_OPTIONS = [
    "Aquecimento Central", "Ar Central", "Ar Condicionado", "Área de Serviço", "Armários Embutidos",
    "Bicicletário", "Churrasqueira", "Churrasqueira Coletiva", "Condomínio Fechado", "Cozinha Americana",
    "Cozinha Planejada", "Diferenciado", "Dormitório com Armários", "Elevador", "Estacionamento",
    "Frente Mar", "Gás Central", "Guarita", "Hidromassagem", "Jardim", "Mobiliado", "Piscina",
    "Piscina Coletiva", "Playground", "Portaria", "Porteiro Eletrônico", "Quadra mar",
    "Quadra de Esportes", "Quintal", "Sacada", "Sacada com Churrasqueira", "Sala com Armários",
    "Sala de Jantar", "Sala Fitness", "Salão de Festas", "Salão Imobiliário", "Sauna", "Segurança",
    "Semi Mobiliado", "Terraço", "Vigilância 24h", "Vista Panorâmica", "Vista para o Mar",
    "Vista frente para o Mar", "Zelador"
  ].freeze
  EXPORT_FIELDS = {
    "codigo" => "Referencia",
    "categoria" => "Categoria",
    "logradouro" => "Endereco",
    "numero" => "Endereco Numero",
    "complemento" => "Endereco Complemento",
    "dormitorios_qtd" => "Dormitorio",
    "valor_venda" => "Valor venda",
    "valor_locacao" => "Valor Aluguel",
    "status" => "Status",
    "bairro" => "Bairro",
    "cidade" => "Cidade",
    "uf" => "UF",
    "cep" => "CEP",
    "suites_qtd" => "Suite",
    "banheiros_qtd" => "Banheiros",
    "vagas_qtd" => "Vagas",
    "valor_condominio" => "Condominio",
    "valor_iptu" => "IPTU",
    "area_privativa_m2" => "Area privativa m2",
    "area_total_m2" => "Area total m2",
    "valor_por_m2" => "Valor do M2",
    "corretor_nome" => "Corretor",
    "proprietario" => "Proprietario",
    "codigo_empreendimento" => "Cod empreendimento"
  }.freeze

  before_action :set_habitation, only: [:edit, :update, :destroy]

  before_action :load_autocomplete_data, only: [:new, :edit, :create, :update]

  def index
    load_index_filters
    @sort_column = sort_column
    @sort_direction = sort_direction
    @habitations = filtered_habitations_scope
                   .order(Arel.sql("habitations.#{@sort_column} #{@sort_direction} NULLS LAST"))
    @filtered_count = @habitations.count

    @habitations = @habitations.paginate(page: params[:page], per_page: 20)
    @page_title = "Gerenciar Imóveis"
    @report_types = REPORT_TYPES
    @export_fields = EXPORT_FIELDS
    @default_export_fields = %w[codigo categoria logradouro numero complemento dormitorios_qtd valor_venda valor_locacao]
    
    # Load filter data
    load_filter_data
  end

  def print
    load_index_filters
    @sort_column = sort_column
    @sort_direction = sort_direction
    @report_type = normalized_report_type
    @report_title = REPORT_TYPES[@report_type]
    @report_generated_at = Time.current
    @full_print_mode = full_print_mode?

    scope = filtered_habitations_scope.order(Arel.sql("habitations.#{@sort_column} #{@sort_direction} NULLS LAST"))
    ids = sanitized_selected_ids
    scope = scope.where(id: ids) if ids.any?

    case @report_type
    when "client_sheet_commercial"
      scope = scope.where(categoria: Habitation::CATEGORIES.select { |c| c.match?(/Comercial|Loja|Galpão|Prédio/i) })
    when "client_sheet_residential"
      scope = scope.where.not(categoria: Habitation::CATEGORIES.select { |c| c.match?(/Comercial|Loja|Galpão|Prédio|Terreno|Área/i) })
    when "client_sheet_land"
      scope = scope.where(categoria: Habitation::CATEGORIES.select { |c| c.match?(/Terreno|Área/i) })
    end

    if @report_type == "property_count_by_broker"
      @broker_rows = scope
        .group("COALESCE(NULLIF(TRIM(corretor_nome), ''), 'Sem corretor')")
        .order(Arel.sql("COUNT(*) DESC"))
        .count
    elsif @report_type == "sale_rent_total_values"
      grouped_rows = scope.to_a.group_by { |h| h.categoria.to_s.strip.presence || "Sem categoria" }
      @summary_rows = grouped_rows.map do |category, rows|
        sale_total = rows.sum { |h| h.valor_venda_cents.to_i } / 100.0
        rent_total = rows.sum { |h| h.valor_locacao_cents.to_i } / 100.0
        {
          category: category,
          total_units: rows.size,
          sale_total: sale_total,
          rent_total: rent_total
        }
      end.sort_by { |row| row[:category].to_s.downcase }
      @summary_totals = {
        units: @summary_rows.sum { |row| row[:total_units] },
        sale_total: @summary_rows.sum { |row| row[:sale_total] },
        rent_total: @summary_rows.sum { |row| row[:rent_total] }
      }
    else
      if @full_print_mode
        setup_full_report(scope)
      else
        setup_paginated_report(scope)
      end
    end

    render layout: false
  end

  def export
    load_index_filters
    @sort_column = sort_column
    @sort_direction = sort_direction
    fields = sanitized_export_fields

    scope = filtered_habitations_scope.order(Arel.sql("habitations.#{@sort_column} #{@sort_direction} NULLS LAST"))
    ids = sanitized_selected_ids
    scope = scope.where(id: ids) if ids.any?

    csv_content = CSV.generate(headers: true, col_sep: export_col_sep) do |csv|
      csv << fields.map { |field| EXPORT_FIELDS[field] || field }
      scope.find_each(batch_size: 500) do |habitation|
        csv << export_row(habitation, fields)
      end
    end

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    send_data csv_content,
              filename: "imoveis_exportacao_#{timestamp}.csv",
              type: "text/csv; charset=utf-8"
  end

  BULK_PUBLISH_CHANNELS = {
    "site"             => { flag: :exibir_no_site_flag, options: [] },
    "netimoveis_2"     => { flag: :publicar_netimoveis_2, options: [] },
    "lais_ai"          => { flag: :publicar_lais_ai, options: [] },
    "loft"             => { flag: :publicar_loft, options: [] },
    "chaves_na_mao"    => { flag: :publicar_chaves_na_mao, options: [:destaque_chaves_na_mao, :periodo_locacao_chaves_na_mao] },
    "casa_mineira"     => { flag: :publicar_casa_mineira, options: [:modelo_casa_mineira] },
    "imovelweb"        => { flag: :publicar_imovelweb, options: [:tipo_publicacao_imovelweb, :mostrar_mapa_imovelweb] },
    "imovelweb_2"      => { flag: :publicar_imovelweb_2, options: [:tipo_publicacao_imovelweb_2, :mostrar_mapa_imovelweb_2] },
    "viva_real_vrsync" => { flag: :publicar_viva_real_vrsync, options: [:tipo_publicacao_viva_real, :divulgar_endereco_viva_real] }
  }.freeze

  def bulk_publish
    ids = resolve_bulk_ids
    action_type = params[:action_type].to_s
    channels = Array(params[:channels]).map(&:to_s) & BULK_PUBLISH_CHANNELS.keys

    if ids.empty?
      return render json: { error: "Nenhum imóvel selecionado." }, status: :unprocessable_entity
    end
    unless %w[publicar despublicar].include?(action_type)
      return render json: { error: "Ação inválida." }, status: :unprocessable_entity
    end
    if channels.empty?
      return render json: { error: "Selecione ao menos um canal." }, status: :unprocessable_entity
    end

    updates = {}
    flag_value = (action_type == "publicar")
    site_flag_touched = false
    portals_touched = []

    channels.each do |channel_key|
      config = BULK_PUBLISH_CHANNELS[channel_key]
      updates[config[:flag]] = flag_value
      site_flag_touched = true if config[:flag] == :exibir_no_site_flag
      portals_touched << channel_key unless channel_key == "site"

      if flag_value
        config[:options].each do |option_key|
          value = params.dig(:channel_options, channel_key, option_key).presence
          updates[option_key] = value if value
        end
      end
    end

    # Bump updated_at so feed ETags e cache_keys das habitations invalidem automaticamente
    updates[:updated_at] = Time.current

    updated_count = 0
    Habitation.transaction do
      updated_count = Habitation.where(id: ids).update_all(updates)
    end

    # Invalida caches individuais (replica o after_save :clear_cache manualmente, pois update_all pula callbacks)
    ids.each do |habitation_id|
      Rails.cache.delete("habitation_#{habitation_id}")
      Rails.cache.delete([Habitation.name, habitation_id])
    end

    # Materialized view de destaques depende de exibir_no_site_flag
    if site_flag_touched && defined?(RefreshFeaturedPropertiesJob)
      RefreshFeaturedPropertiesJob.perform_later
    end

    # Bump last_feed_at nas integrations afetadas pra sinalizar no admin que houve mudança
    if portals_touched.any?
      portal_keys = Habitation::PORTAL_PUBLICATION_FIELDS.select { |_, col| updates.key?(col) }.keys
      PortalIntegration.where(portal: portal_keys).update_all(updated_at: Time.current) if portal_keys.any?
    end

    render json: {
      updated: updated_count,
      action_type: action_type,
      channels: channels
    }
  end

  def bulk_publish_eligibility
    ids = resolve_bulk_ids
    channel = params[:channel].to_s
    action_type = params[:action_type].to_s
    config = BULK_PUBLISH_CHANNELS[channel]

    unless config && %w[publicar despublicar].include?(action_type)
      return render json: { error: "Parâmetros inválidos." }, status: :unprocessable_entity
    end

    flag_column = config[:flag]
    target_flag = (action_type == "despublicar")
    eligible = Habitation.where(id: ids).where(flag_column => target_flag).count

    render json: { total: ids.size, eligible: eligible }
  end

  def new
    @habitation = Habitation.new
    @habitation.build_address
    @page_title = "Novo Imóvel"
  end

  def create
    @habitation = Habitation.new(habitation_params)
    assign_proprietor_from_legacy_fields(@habitation) if current_admin_user&.admin?

    if @habitation.save
      redirect_to admin_habitations_path, notice: "Imóvel criado com sucesso."
    else
      load_autocomplete_data
      render :new, status: :unprocessable_entity
    end
  end


  def edit
    @page_title = "Editar Imóvel: #{@habitation.codigo}"
  end

  def update
    @habitation.assign_attributes(habitation_params)
    assign_proprietor_from_legacy_fields(@habitation) if current_admin_user&.admin?
    if @habitation.save
      redirect_to admin_habitations_path, notice: "Imóvel atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless current_admin_user&.admin?
      redirect_to admin_habitations_path, alert: "Apenas administradores podem excluir imóveis."
      return
    end

    @habitation.destroy
    redirect_to admin_habitations_path, notice: "Imóvel excluído com sucesso."
  end

  def sync
    @habitation = Habitation.find(params[:id])
    result = SyncPropertyService.new(@habitation.codigo).perform

    if result[:success]
      redirect_to edit_admin_habitation_path(@habitation), notice: "Imóvel sincronizado com o Vista com sucesso!"
    else
      redirect_to edit_admin_habitation_path(@habitation), alert: "Erro na sincronização: #{result[:error]}"
    end
  end

  # Remove um anexo individual (ficha de cadastro ou autorização) do imóvel.
  # Restrito aos imóveis do habitation; valida o nome da associação por allowlist.
  def purge_attachment
    @habitation = Habitation.find(params[:id])
    association = params[:association].to_s
    allowed = %w[fichas_cadastro autorizacoes_venda photos]
    unless allowed.include?(association)
      redirect_to edit_admin_habitation_path(@habitation, anchor: "documents"), alert: "Anexo inválido."
      return
    end

    attachment = @habitation.public_send(association).attachments.find_by(id: params[:attachment_id])
    if attachment.nil?
      redirect_to edit_admin_habitation_path(@habitation, anchor: "documents"), alert: "Anexo não encontrado."
      return
    end

    attachment.purge_later
    redirect_to edit_admin_habitation_path(@habitation, anchor: "documents"), notice: "Anexo removido."
  end

  private

  def scope_habitations_by_permission
    return if owns_all_resource?(:imoveis)
    id = (params[:id] || params[:habitation_id]).to_i
    return if id.zero?
    unless Habitation.where(id: id, admin_user_id: current_admin_user.id).exists?
      redirect_to admin_habitations_path, alert: "Você não tem acesso a este imóvel."
    end
  end

  def sort_column
    Habitation.column_names.include?(params[:sort]) ? params[:sort] : "data_cadastro_crm"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
  helper_method :sort_column, :sort_direction

  def set_habitation
    @habitation = Habitation.find(params[:id])
    @habitation.build_address if @habitation.address.nil?
  end

  def load_autocomplete_data
    @proprietors = Proprietor.select(:id, :name).order(name: :asc)
    @developments = Habitation.empreendimentos
                              .select(:id, :slug, :codigo, :nome_empreendimento, :constructor_id)
                              .where("NULLIF(TRIM(nome_empreendimento), '') IS NOT NULL AND nome_empreendimento != '.'")
                              .order(nome_empreendimento: :asc)
    @brokers = AdminUser.select(:id, :name).order(name: :asc)

    cached = Rails.cache.fetch("admin/habitations/form_options/v1", expires_in: 2.minutes) do
      base_address_scope = Habitation.left_outer_joins(:address)

      {
        cities: base_address_scope
          .where("NULLIF(TRIM(COALESCE(addresses.cidade, habitations.cidade)), '') IS NOT NULL AND COALESCE(addresses.cidade, habitations.cidade) != '.'")
          .distinct
          .pluck(Arel.sql("COALESCE(addresses.cidade, habitations.cidade)"))
          .sort,
        neighborhoods: base_address_scope
          .where("NULLIF(TRIM(COALESCE(addresses.bairro, habitations.bairro)), '') IS NOT NULL AND COALESCE(addresses.bairro, habitations.bairro) != '.'")
          .distinct
          .pluck(Arel.sql("COALESCE(addresses.bairro, habitations.bairro)"))
          .sort,
        commercial_neighborhoods: base_address_scope
          .where("NULLIF(TRIM(addresses.bairro_comercial), '') IS NOT NULL AND addresses.bairro_comercial != '.'")
          .distinct
          .pluck(Arel.sql("addresses.bairro_comercial"))
          .sort,
        badges: AttributeOption.where(context: 'habitation', category: 'unique_feature').order(name: :asc).pluck(:name),
        imediacoes_options: AttributeOption.where(context: 'habitation', category: 'imediacoes').order(name: :asc).pluck(:name),
        internal_features: AttributeOption.where(context: 'habitation', category: 'feature').order(name: :asc).pluck(:name),
        external_features: AttributeOption.where(context: 'habitation', category: 'infrastructure').order(name: :asc).pluck(:name)
      }
    end

    @cities = cached[:cities]
    @neighborhoods = cached[:neighborhoods]
    @commercial_neighborhoods = cached[:commercial_neighborhoods]
    @badges = cached[:badges]
    @imediacoes_options = cached[:imediacoes_options]
    @internal_features = cached[:internal_features]
    @external_features = cached[:external_features]
    @categories = (
      Habitation::CATEGORIES +
      Habitation.where("NULLIF(TRIM(categoria), '') IS NOT NULL AND categoria != '.'").distinct.pluck(:categoria) +
      ["Empreendimento"]
    ).compact.uniq.sort
    @status_options = (
      Habitation::STATUS_OPTIONS +
      Habitation.where("NULLIF(TRIM(status), '') IS NOT NULL AND status != '.'").distinct.pluck(:status)
    ).compact.uniq
  end

  def load_filter_data
    @filter_categories = Habitation.where("NULLIF(TRIM(categoria), '') IS NOT NULL AND categoria != '.'")
                                   .distinct.pluck(:categoria).sort
    @filter_cities = Habitation.left_outer_joins(:address)
                               .where("NULLIF(TRIM(COALESCE(addresses.cidade, habitations.cidade)), '') IS NOT NULL AND COALESCE(addresses.cidade, habitations.cidade) != '.'")
                               .distinct
                               .pluck(Arel.sql("COALESCE(addresses.cidade, habitations.cidade)"))
                               .sort
    @filter_bairros_comerciais = Habitation.left_outer_joins(:address)
                                           .where("NULLIF(TRIM(addresses.bairro_comercial), '') IS NOT NULL AND addresses.bairro_comercial != '.'")
                                           .distinct
                                           .pluck(Arel.sql("addresses.bairro_comercial"))
                                           .sort
    @filter_statuses = Habitation.where("NULLIF(TRIM(status), '') IS NOT NULL AND status != '.'")
                                 .distinct.pluck(:status).sort
    existing_key_locations = Habitation.where("NULLIF(TRIM(key_location), '') IS NOT NULL")
                                       .distinct
                                       .pluck(:key_location)
                                       .sort
    @filter_key_locations = (Habitation::KEY_LOCATION_OPTIONS + existing_key_locations).uniq
    @filter_empreendimentos = Habitation.empreendimentos
                                        .where("NULLIF(TRIM(codigo), '') IS NOT NULL")
                                        .where("NULLIF(TRIM(nome_empreendimento), '') IS NOT NULL AND nome_empreendimento != '.'")
                                        .order(nome_empreendimento: :asc)
                                        .pluck(:nome_empreendimento, :codigo)
    @filter_brokers = AdminUser.order(name: :asc).pluck(:name, :id)
    @filter_proprietors = Proprietor.order(name: :asc).pluck(:name, :id)
    @filter_situacoes = (Habitation::SITUATIONS + Habitation.where("NULLIF(TRIM(situacao), '') IS NOT NULL AND situacao != '.'")
                                                          .distinct
                                                          .pluck(:situacao)).uniq.sort
    @filter_faces = (Habitation::FACES + Habitation.where("NULLIF(TRIM(face), '') IS NOT NULL AND face != '.'")
                                               .distinct
                                               .pluck(:face)).uniq.sort
    @filter_ocupacao_statuses = (Habitation::OCUPACAO_STATUS + Habitation.where("NULLIF(TRIM(ocupacao_status), '') IS NOT NULL AND ocupacao_status != '.'")
                                                                           .distinct
                                                                           .pluck(:ocupacao_status)).uniq.sort
    @filter_estado_conservacoes = (Habitation::ESTADO_CONSERVACAO + Habitation.where("NULLIF(TRIM(estado_conservacao), '') IS NOT NULL AND estado_conservacao != '.'")
                                                                                 .distinct
                                                                                 .pluck(:estado_conservacao)).uniq.sort
    @filter_regioes_foco = (Habitation::REGIAO_FOCO_OPTIONS + Habitation.where("NULLIF(TRIM(regiao_foco), '') IS NOT NULL AND regiao_foco != '.'")
                                                                          .distinct
                                                                          .pluck(:regiao_foco)).uniq.sort
  end

  def extract_multi_select_integers(param_key)
    Array(params[param_key])
      .flatten
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
      .map(&:to_i)
      .reject(&:zero?)
      .uniq
  end

  def parse_decimal_param(raw_value)
    value = raw_value.to_s.strip
    return nil if value.blank?

    normalized = value.gsub(/[^\d,.\-]/, '').tr(',', '.')
    decimal_value = normalized.to_f
    decimal_value.positive? ? decimal_value : nil
  end

  def load_index_filters
    @q = params[:q]
    @status = params[:status]
    @categoria = params[:categoria]
    @logradouro = params[:logradouro]
    @numero = params[:numero]
    @cep = params[:cep]
    @cidade = params[:cidade]
    @bairro = params[:bairro]
    @bairro_comercial = params[:bairro_comercial]
    @dorms = extract_multi_select_integers(:dorms)
    @suites = extract_multi_select_integers(:suites)
    @vagas = extract_multi_select_integers(:vagas)
    @banheiros = extract_multi_select_integers(:banheiros)
    @situacao = params[:situacao]
    @face = params[:face]
    @ocupacao_status = params[:ocupacao_status]
    @estado_conservacao = params[:estado_conservacao]
    @regiao_foco = params[:regiao_foco]
    @promotion_status = params[:promotion_status]
    @accepts_exchange = params[:accepts_exchange]
    @permuta_vehicle = params[:permuta_vehicle]
    @permuta_property = params[:permuta_property]
    @permuta_others = params[:permuta_others]
    @foto_classificacoes = Array(params[:foto_classificacao]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    @permuta_location = params[:permuta_location]
    @amenities = Array(params[:amenities]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    @permuta_min_dorms = params[:permuta_min_dorms]
    @permuta_min_suites = params[:permuta_min_suites]
    @permuta_min_garagens = params[:permuta_min_garagens]
    @key_location = params[:key_location]
    @salute_rental_management = params[:salute_rental_management]
    @empreendimento_codigo = params[:empreendimento_codigo]
    @corretor_id = params[:corretor_id]
    @proprietor_id = current_admin_user&.admin? ? params[:proprietor_id] : nil
    @festival_salute = params[:festival_salute]
    @exibir_no_site_salute = params[:exibir_no_site_salute]
    @publicar_imovelweb_2 = params[:publicar_imovelweb_2]
    @publicar_netimoveis_2 = params[:publicar_netimoveis_2]
    @publicar_lais_ai = params[:publicar_lais_ai]
    @publicar_loft = params[:publicar_loft]
    @publicar_chaves_na_mao = params[:publicar_chaves_na_mao]
    @publicar_casa_mineira = params[:publicar_casa_mineira]
    @publicar_imovelweb = params[:publicar_imovelweb]
    @publicar_viva_real_vrsync = params[:publicar_viva_real_vrsync]
    @somente_com_imagens = params[:somente_com_imagens]
    @somente_sem_imagens = params[:somente_sem_imagens]
    @tem_placa = params[:tem_placa]
    @exclusivo = params[:exclusivo]
    @area_total_min = params[:area_total_min]
    @area_total_max = params[:area_total_max]
    @area_privativa_min = params[:area_privativa_min]
    @area_privativa_max = params[:area_privativa_max]
    @min_price = params[:min_price].to_s.gsub(/[^\d]/, '').to_i
    @max_price = params[:max_price].to_s.gsub(/[^\d]/, '').to_i
    @permuta_min_value = params[:permuta_min_value].to_s.gsub(/[^\d]/, '').to_i
    @scope = params[:scope]
    @captacao_inicio = params[:captacao_inicio]
    @captacao_fim = params[:captacao_fim]
    @atualizacao_inicio = params[:atualizacao_inicio]
    @atualizacao_fim = params[:atualizacao_fim]
  end

  def filtered_habitations_scope
    scope = Habitation.left_outer_joins(:address)
    scope = scope.where(admin_user_id: current_admin_user.id) unless owns_all_resource?(:imoveis)

    if @q.present?
      scope = scope.where(
        "codigo ILIKE :q OR titulo_anuncio ILIKE :q OR descricao_web ILIKE :q OR " \
        "COALESCE(addresses.logradouro, habitations.endereco) ILIKE :q OR " \
        "COALESCE(addresses.bairro, habitations.bairro) ILIKE :q OR " \
        "COALESCE(addresses.bairro_comercial, '') ILIKE :q OR " \
        "COALESCE(addresses.cidade, habitations.cidade) ILIKE :q",
        q: "%#{@q}%"
      )
    end

    scope = scope.where(status: @status) if @status.present? && @status != "Todos"
    scope = scope.where(categoria: @categoria) if @categoria.present? && @categoria != "Todas"
    scope = scope.where("COALESCE(addresses.logradouro, habitations.endereco) ILIKE ?", "%#{@logradouro}%") if @logradouro.present?
    scope = scope.where("COALESCE(addresses.numero, '') ILIKE ?", "%#{@numero}%") if @numero.present?
    scope = scope.where("COALESCE(addresses.cep, habitations.cep, '') ILIKE ?", "%#{@cep}%") if @cep.present?
    scope = scope.where("COALESCE(addresses.cidade, habitations.cidade) = ?", @cidade) if @cidade.present?
    scope = scope.where("COALESCE(addresses.bairro, habitations.bairro) ILIKE ?", "%#{@bairro}%") if @bairro.present?
    scope = scope.where("COALESCE(addresses.bairro_comercial, '') ILIKE ?", "%#{@bairro_comercial}%") if @bairro_comercial.present?
    scope = scope.where(dormitorios_qtd: @dorms) if @dorms.any?
    scope = scope.where(suites_qtd: @suites) if @suites.any?
    scope = scope.where(vagas_qtd: @vagas) if @vagas.any?
    scope = scope.where(banheiros_qtd: @banheiros) if @banheiros.any?
    scope = scope.where(situacao: @situacao) if @situacao.present?
    scope = scope.where(face: @face) if @face.present?
    scope = scope.where(ocupacao_status: @ocupacao_status) if @ocupacao_status.present?
    scope = scope.where(estado_conservacao: @estado_conservacao) if @estado_conservacao.present?
    scope = scope.where(regiao_foco: @regiao_foco) if @regiao_foco.present?
    @amenities.each { |amenity| scope = apply_amenity_filter(scope, amenity) } if @amenities.any?

    if @promotion_status == "with_promo"
      scope = scope.where("valor_venda_anterior_cents > valor_venda_cents AND valor_venda_cents > 0")
    elsif @promotion_status == "without_promo"
      scope = scope.where("NOT (valor_venda_anterior_cents > valor_venda_cents AND valor_venda_cents > 0)")
    end

    if @accepts_exchange == "1"
      scope = scope.where(aceita_permuta_flag: true)
    elsif @accepts_exchange == "0"
      scope = scope.where(aceita_permuta_flag: false)
    end

    scope = apply_boolean_filter(scope, @permuta_vehicle, :aceita_permuta_veiculo_flag)
    scope = apply_boolean_filter(scope, @permuta_property, :aceita_permuta_imovel_flag)
    scope = apply_boolean_filter(scope, @permuta_others, :aceita_permuta_outros_flag)
    scope = scope.where(foto_classificacao: @foto_classificacoes) if @foto_classificacoes.any?

    if @permuta_min_value > 0
      min_permuta_cents = @permuta_min_value * 100
      scope = scope.where(
        "COALESCE(permuta_valor_cents, 0) >= :min OR COALESCE(valor_aceito_permuta_cents, 0) >= :min",
        min: min_permuta_cents
      )
    end

    scope = scope.where("permuta_localizacao ILIKE ?", "%#{@permuta_location}%") if @permuta_location.present?
    scope = scope.where("COALESCE(permuta_dormitorios_qtd, 0) >= ?", @permuta_min_dorms.to_i) if @permuta_min_dorms.present?
    scope = scope.where("COALESCE(permuta_suites_qtd, 0) >= ?", @permuta_min_suites.to_i) if @permuta_min_suites.present?
    scope = scope.where("COALESCE(permuta_garagens_qtd, 0) >= ?", @permuta_min_garagens.to_i) if @permuta_min_garagens.present?
    scope = scope.where(key_location: @key_location) if @key_location.present?
    scope = scope.where("codigo_empreendimento = :codigo OR codigo = :codigo", codigo: @empreendimento_codigo) if @empreendimento_codigo.present?
    if @corretor_id.present?
      broker_name = AdminUser.where(id: @corretor_id).pick(:name).to_s
      scope = scope.left_outer_joins(:broker_assignments)
                   .where("habitation_broker_assignments.admin_user_id = :id OR habitations.corretor_nome ILIKE :name", id: @corretor_id.to_i, name: "%#{broker_name}%")
                   .distinct
    end
    scope = scope.where(proprietor_id: @proprietor_id) if @proprietor_id.present?

    if @salute_rental_management == "1"
      scope = scope.where(salute_rental_management_flag: true)
    elsif @salute_rental_management == "0"
      scope = scope.where(salute_rental_management_flag: false)
    end

    scope = scope.where("valor_venda_cents >= ? OR valor_locacao_cents >= ?", @min_price * 100, @min_price * 100) if @min_price > 0
    scope = scope.where("valor_venda_cents <= ? OR valor_locacao_cents <= ?", @max_price * 100, @max_price * 100) if @max_price > 0

    captacao_inicio = parse_date_param(@captacao_inicio)
    captacao_fim = parse_date_param(@captacao_fim)
    if captacao_inicio
      scope = scope.where("COALESCE(habitations.data_cadastro_crm, habitations.created_at) >= ?", captacao_inicio.beginning_of_day)
    end
    if captacao_fim
      scope = scope.where("COALESCE(habitations.data_cadastro_crm, habitations.created_at) <= ?", captacao_fim.end_of_day)
    end

    atualizacao_inicio = parse_date_param(@atualizacao_inicio)
    atualizacao_fim = parse_date_param(@atualizacao_fim)
    if atualizacao_inicio
      scope = scope.where("COALESCE(habitations.data_atualizacao_crm, habitations.updated_at) >= ?", atualizacao_inicio.beginning_of_day)
    end
    if atualizacao_fim
      scope = scope.where("COALESCE(habitations.data_atualizacao_crm, habitations.updated_at) <= ?", atualizacao_fim.end_of_day)
    end

    area_total_min = parse_decimal_param(@area_total_min)
    area_total_max = parse_decimal_param(@area_total_max)
    area_privativa_min = parse_decimal_param(@area_privativa_min)
    area_privativa_max = parse_decimal_param(@area_privativa_max)

    scope = scope.where("area_total_m2 >= ?", area_total_min) if area_total_min
    scope = scope.where("area_total_m2 <= ?", area_total_max) if area_total_max
    scope = scope.where("area_privativa_m2 >= ?", area_privativa_min) if area_privativa_min
    scope = scope.where("area_privativa_m2 <= ?", area_privativa_max) if area_privativa_max
    scope = apply_boolean_filter(scope, @festival_salute, :festival_salute_flag)
    scope = apply_boolean_filter(scope, @exibir_no_site_salute, :exibir_no_site_salute_flag)
    scope = apply_boolean_filter(scope, @publicar_imovelweb_2, :publicar_imovelweb_2)
    scope = apply_boolean_filter(scope, @publicar_netimoveis_2, :publicar_netimoveis_2)
    scope = apply_boolean_filter(scope, @publicar_lais_ai, :publicar_lais_ai)
    scope = apply_boolean_filter(scope, @publicar_loft, :publicar_loft)
    scope = apply_boolean_filter(scope, @publicar_chaves_na_mao, :publicar_chaves_na_mao)
    scope = apply_boolean_filter(scope, @publicar_casa_mineira, :publicar_casa_mineira)
    scope = apply_boolean_filter(scope, @publicar_imovelweb, :publicar_imovelweb)
    scope = apply_boolean_filter(scope, @publicar_viva_real_vrsync, :publicar_viva_real_vrsync)

    photos_condition = "(jsonb_typeof(habitations.pictures) = 'array' AND jsonb_array_length(habitations.pictures) > 0) OR (EXISTS (SELECT 1 FROM active_storage_attachments WHERE active_storage_attachments.record_id = habitations.id AND active_storage_attachments.record_type = 'Habitation'))"
    if @somente_com_imagens == "1" && @somente_sem_imagens != "1"
      scope = scope.where(photos_condition)
    elsif @somente_sem_imagens == "1" && @somente_com_imagens != "1"
      scope = scope.where("NOT (#{photos_condition})")
    end

    scope = apply_boolean_filter(scope, @tem_placa, :tem_placa_flag)
    scope = apply_boolean_filter(scope, @exclusivo, :exclusivo_flag)

    case @scope
    when "oportunidade" then scope = scope.opportunity
    when "frente_mar" then scope = scope.where(frente_mar_avenida_atlantica_flag: true).or(scope.where(vista_frente_mar_flag: true))
    when "lancamento" then scope = scope.where(lancamento_flag: true)
    when "na_planta" then scope = scope.where("situacao ILIKE ?", "%Planta%")
    when "mobiliado" then scope = scope.where(mobiliado_flag: true)
    when "sacada" then scope = scope.where(varanda_gourmet_flag: true)
    when "decorado" then scope = scope.where(decorado_flag: true)
    end

    scope
  end

  def normalized_report_type
    report_type = params[:report_type].to_s
    REPORT_TYPES.key?(report_type) ? report_type : "property_list"
  end

  def sanitized_selected_ids
    values = params[:selected_ids]
    array = values.is_a?(String) ? values.split(",") : Array(values)
    array.map(&:to_i).select(&:positive?)
  end

  # Retorna os IDs alvos do bulk. Se o usuário marcou \"selecionar tudo\",
  # reconstruímos a base filtrada (respeitando filtros ativos) e pegamos
  # todos os IDs. Caso contrário, usa só os IDs marcados individualmente.
  def resolve_bulk_ids
    if ActiveModel::Type::Boolean.new.cast(params[:select_all_filtered])
      # Reaplica os mesmos filtros da listagem — params[:filters] vem como hash
      # das query params originais.
      reapply_filter_params!
      load_index_filters
      filtered_habitations_scope.reorder(nil).pluck(:id)
    else
      sanitized_selected_ids
    end
  end

  def reapply_filter_params!
    filters = params[:filters]
    return unless filters.respond_to?(:each)
    filters.each do |key, value|
      next if params.key?(key)  # não sobrescreve params já setados
      params[key] = value
    end
  end

  def sanitized_export_fields
    selected = Array(params[:fields]).map(&:to_s)
    valid = selected.select { |field| EXPORT_FIELDS.key?(field) }
    valid -= %w[proprietario] unless current_admin_user&.admin?
    valid.presence || %w[codigo categoria logradouro numero complemento dormitorios_qtd valor_venda valor_locacao]
  end

  def export_col_sep
    params[:data_format].to_s == "csv_comma" ? "," : ";"
  end

  def export_row(habitation, fields)
    fields.map do |field|
      case field
      when "codigo" then habitation.codigo
      when "categoria" then habitation.categoria
      when "status" then habitation.status
      when "logradouro" then habitation.logradouro || habitation.endereco
      when "numero" then habitation.numero
      when "complemento" then habitation.complemento
      when "bairro" then habitation.bairro
      when "cidade" then habitation.cidade
      when "uf" then habitation.uf
      when "cep" then habitation.cep
      when "dormitorios_qtd" then habitation.dormitorios_qtd
      when "suites_qtd" then habitation.suites_qtd
      when "banheiros_qtd" then habitation.banheiros_qtd
      when "vagas_qtd" then habitation.vagas_qtd
      when "valor_venda" then habitation.valor_venda_formatted
      when "valor_locacao" then habitation.valor_locacao_formatted
      when "valor_condominio" then habitation.valor_condominio_formatted
      when "valor_iptu" then habitation.valor_iptu_formatted
      when "area_privativa_m2" then habitation.area_privativa_m2
      when "area_total_m2" then habitation.area_total_m2
      when "valor_por_m2" then habitation.valor_por_m2_formatted
      when "corretor_nome" then habitation.corretor_nome
      when "proprietario" then habitation.proprietario
      when "codigo_empreendimento" then habitation.codigo_empreendimento
      else habitation.public_send(field)
      end
    end
  end

  def apply_boolean_filter(scope, raw_param, column_name)
    case raw_param
    when '1' then scope.where(column_name => true)
    when '0' then scope.where(column_name => false)
    else scope
    end
  end

  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def apply_amenity_filter(scope, amenity)
    key = I18n.transliterate(amenity.to_s).downcase
    pattern = "%" + key.gsub(/[^a-z0-9]+/, "%") + "%"

    case key
    when /frente mar/
      scope.where("frente_mar_avenida_atlantica_flag = true OR vista_frente_mar_flag = true")
    when /vista frente para o mar/
      scope.where(vista_frente_mar_flag: true)
    when /vista para o mar/
      scope.where("vista_frente_mar_flag = true OR unaccent(lower(descricao_web)) ILIKE unaccent(?)", "%vista%mar%")
    when /piscina/
      scope.where("piscina_flag = true OR COALESCE(hidromassagem_qtd, 0) > 0 OR " \
                  "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) value WHERE unaccent(lower(value)) ILIKE unaccent('%piscina%')))")
    when /elevador/
      scope.where("COALESCE(elevadores_qtd, 0) > 0")
    when /sacada/
      scope.where("varanda_gourmet_flag = true OR " \
                  "(jsonb_typeof(caracteristicas) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(caracteristicas) value WHERE unaccent(lower(value)) ILIKE unaccent('%sacada%'))) OR " \
                  "(jsonb_typeof(caracteristicas) = 'object' AND EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) kv WHERE unaccent(lower(kv.key)) ILIKE unaccent('%sacada%') OR unaccent(lower(kv.value)) ILIKE unaccent('%sacada%')))")
    when /mobiliado/
      scope.where("mobiliado_flag = true OR " \
                  "(jsonb_typeof(caracteristicas) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(caracteristicas) value WHERE unaccent(lower(value)) ILIKE unaccent('%mobiliado%'))) OR " \
                  "(jsonb_typeof(caracteristicas) = 'object' AND EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) kv WHERE unaccent(lower(kv.key)) ILIKE unaccent('%mobiliado%') OR unaccent(lower(kv.value)) ILIKE unaccent('%mobiliado%')))")
    else
      scope.where(
        "(jsonb_typeof(caracteristicas) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(caracteristicas) value WHERE unaccent(lower(value)) ILIKE unaccent(:pattern))) OR " \
        "(jsonb_typeof(caracteristicas) = 'object' AND EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) kv WHERE unaccent(lower(kv.key)) ILIKE unaccent(:pattern) OR unaccent(lower(kv.value)) ILIKE unaccent(:pattern))) OR " \
        "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) value WHERE unaccent(lower(value)) ILIKE unaccent(:pattern))) OR " \
        "unaccent(lower(COALESCE(descricao_web, ''))) ILIKE unaccent(:pattern)",
        pattern: pattern
      )
    end
  end

  def setup_paginated_report(scope)
    per_page = REPORT_PAGE_SIZE.fetch(@report_type, 27)
    total_entries = scope.count
    raw_pages = (total_entries.to_f / per_page).ceil

    @report_total_entries = total_entries
    @report_total_pages = [[raw_pages, 1].max, REPORT_MAX_PAGES].min
    @report_limited_to_max_pages = raw_pages > REPORT_MAX_PAGES

    requested_page = params[:page].to_i
    @report_page = requested_page.positive? ? requested_page : 1
    @report_page = @report_total_pages if @report_page > @report_total_pages

    offset = (@report_page - 1) * per_page
    @habitations = scope.offset(offset).limit(per_page)
  end

  def setup_full_report(scope)
    per_page = REPORT_PAGE_SIZE.fetch(@report_type, 27)
    raw_total_entries = scope.count
    max_entries = per_page * REPORT_MAX_PAGES
    effective_total_entries = [raw_total_entries, max_entries].min

    rows = scope.limit(max_entries).to_a
    @report_pages_data = rows.each_slice(per_page).to_a

    @report_total_entries = effective_total_entries
    @report_total_pages = @report_pages_data.size
    @report_page = 1
    @report_limited_to_max_pages = raw_total_entries > max_entries
  end

  def full_print_mode?
    params[:full_print].to_s != "0"
  end

  def habitation_params
    permitted = params.require(:habitation).permit(
      :slug, :categoria, :status, :situacao, :tipo, :codigo_empreendimento, 
      :nome_empreendimento,
      :dormitorios_qtd, :suites_qtd, :salas_qtd, :varandas_qtd, :banheiros_qtd, :hidromassagem_qtd, :vagas_qtd, :elevadores_qtd, 
      :area_privativa_m2, :area_total_m2, :area_terreno_m2, :area_util_m2, 
      :valor_venda_formatted, :valor_locacao_formatted, :valor_condominio_formatted, :valor_iptu_formatted, :valor_por_m2_formatted, 
      :valor_locacao_anterior_formatted, :valor_aceito_permuta_formatted, :permuta_valor_formatted, :saldo_devedor_formatted,
      :descricao_web, :descricao_interna, :titulo_anuncio, :observacoes, 
      :condicoes_negociacao, :observacoes_visitas,
      :corretor_nome, :corretor_telefone, :corretor_email, :proprietario_codigo,
      :proprietario, :proprietario_celular, :proprietario_telefone_comercial,
      :proprietario_telefone_residencial, :proprietario_email,
      :exibir_no_site_flag, :destaque_web_flag, :lancamento_flag, :aceita_permuta_flag, 
      :aceita_doacao_flag,
      :aceita_permuta_veiculo_flag, :aceita_permuta_imovel_flag, :aceita_permuta_outros_flag,
      :aceita_financiamento_flag, :mobiliado_flag, :data_entrega, :status_vista, 
      :meta_title, :meta_description, :meta_keywords, 
      :piscina_flag, :lavabo_flag, :varanda_gourmet_flag, :bloco, :lote,
      :banheiro_social_qtd, :decorado_flag, :aptos_andar, :aptos_edificio,
      :garden_flag, :quadra_mar_flag, :sem_mobilia_flag, 
      :valor_venda_anterior_cents, :valor_venda_anterior_formatted, :valor_total_aluguel_cents, :valor_promocional_formatted, 
      :proprietario, :inscricao_imobiliaria, :descricao_empreendimento,
      :categoria_grupo, :tour_virtual,
      :constructor_id, :proprietor_id, :admin_user_id,
      :terceira_avenida_flag, :arriba_flag, :avenida_brasil_flag, :bairro_fazenda_itajai_flag, 
      :balneario_picarras_flag, :barra_flag, :barra_norte_flag, :barra_sul_flag, 
      :cabecudas_flag, :camboriu_flag, :centro_flag, :estaleirinho_flag, 
      :frente_mar_avenida_atlantica_flag, :itajai_flag, :itapema_flag, :nacoes_flag, 
      :pioneiros_flag, :praia_brava_flag, :praia_dos_amores_flag, :vista_frente_mar_flag, 
      :festival_salute_flag, :exibir_no_site_salute_flag, :tem_placa_flag, :imovel_dwv,
      :publicar_imovelweb_2, :publicar_netimoveis_2, :publicar_lais_ai, :publicar_loft,
      :publicar_chaves_na_mao, :publicar_casa_mineira, :publicar_imovelweb, :publicar_viva_real_vrsync,
      :destaque_chaves_na_mao, :periodo_locacao_chaves_na_mao,
      :modelo_casa_mineira,
      :tipo_publicacao_viva_real, :divulgar_endereco_viva_real,
      :tipo_publicacao_imovelweb, :mostrar_mapa_imovelweb,
      :tipo_publicacao_imovelweb_2, :mostrar_mapa_imovelweb_2,
      :exclusivo_flag, :ocupacao_status, :estado_conservacao,
      :andar, :ano_construcao, :demi_suites_qtd, :numero_box, :tipo_vaga,
      :dimensoes_terreno, :topografia, :foto_classificacao, :podcast_url,
      :matricula_imovel, :zona, :numero_prestacoes, :responsavel_reserva, :zelador_nome, :zelador_telefone, :regiao_foco,
      :construtora, :tipo_fachada, :andares_qtd, :perfil_construcao, :face,
      :tipo_veiculo_aceito_permuta, :ano_minimo_veiculo_aceito_permuta,
      :permuta_localizacao, :permuta_dormitorios_qtd, :permuta_suites_qtd, :permuta_garagens_qtd,
      :agenciador, :captador_commission_percentage, :broker_commission_percentage,
      :salute_rental_management_flag, :home_corporate_flag, :home_corporate_position,
      :key_location, :key_location_notes, :ordered_photo_ids,
      videos: [], plantas: [], fotos_empreendimento: [], photos: [],
      fichas_cadastro: [], autorizacoes_venda: [],
      meta_keywords: [],
      caracteristicas: [], infra_estrutura: [], caracteristica_unica: [],
      broker_assignments_attributes: [:id, :admin_user_id, :role, :commission_type, :commission_value, :observations, :_destroy],
      address_attributes: [:id, :tipo_endereco, :logradouro, :numero, :complemento, :bairro, :bairro_comercial, :cidade, :uf, :cep, :pais, :latitude, :longitude, :_destroy, { imediacoes: [] }]
    )

    unless current_admin_user&.admin?
      proprietor_locked_fields = %i[
        proprietario proprietario_codigo proprietario_email proprietario_celular
        proprietario_telefone_comercial proprietario_telefone_residencial proprietor_id
      ]
      proprietor_locked_fields.each { |field| permitted.delete(field) }
    end

    # Campos presentes no formulário, mas ainda sem coluna no schema atual.
    # São descartados para evitar UnknownAttributeError ao inicializar o model.
    permitted.delete(:salas_qtd)
    permitted.delete(:varandas_qtd)

    permitted
  end

  def assign_proprietor_from_legacy_fields(habitation)
    if habitation.proprietor_id.present?
      selected = Proprietor.find_by(id: habitation.proprietor_id)
      if selected.present?
        habitation.proprietario = selected.name
        habitation.proprietario_codigo = selected.vista_code if selected.vista_code.present?
        habitation.proprietario_email = selected.email if selected.email.present?
        habitation.proprietario_celular = selected.mobile_phone if selected.mobile_phone.present?
        habitation.proprietario_telefone_comercial = selected.business_phone if selected.business_phone.present?
        habitation.proprietario_telefone_residencial = selected.residential_phone if selected.residential_phone.present?
      end
      return
    end

    name = habitation.proprietario.to_s.strip
    email = habitation.proprietario_email.to_s.strip
    phone = habitation.proprietario_celular.to_s.strip
    vista_code = habitation.proprietario_codigo.to_s.strip
    return if name.blank? && email.blank? && phone.blank? && vista_code.blank?

    proprietor = nil
    proprietor = Proprietor.find_by(vista_code: vista_code) if vista_code.present?
    proprietor ||= Proprietor.find_by(email: email) if email.present?
    proprietor ||= Proprietor.find_by(name: name) if name.present?
    proprietor ||= Proprietor.new(name: name.presence || "Proprietário sem nome", role: :owner)

    proprietor.name = name if name.present?
    proprietor.email = email if email.present?
    proprietor.mobile_phone = phone if phone.present?
    proprietor.business_phone ||= habitation.proprietario_telefone_comercial.presence
    proprietor.residential_phone ||= habitation.proprietario_telefone_residencial.presence
    proprietor.vista_code = vista_code if vista_code.present?
    proprietor.save!

    habitation.proprietor_id = proprietor.id
  rescue ActiveRecord::RecordInvalid
    # Se o proprietário não puder ser salvo, não bloqueia o fluxo do imóvel.
    nil
  end
end

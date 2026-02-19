class Admin::HabitationsController < Admin::BaseController
  before_action :set_habitation, only: [:edit, :update, :destroy]

  before_action :load_autocomplete_data, only: [:new, :edit, :create, :update]

  def index
    @q = params[:q]
    @status = params[:status]
    @categoria = params[:categoria]
    
    # Advanced Filters
    @cidade = params[:cidade]
    @bairro = params[:bairro]
    @dorms = params[:dorms]
    @suites = params[:suites]
    @vagas = params[:vagas]
    @promotion_status = params[:promotion_status]
    @accepts_exchange = params[:accepts_exchange]
    @key_location = params[:key_location]
    @salute_rental_management = params[:salute_rental_management]
    @min_price = params[:min_price].to_s.gsub(/[^\d]/, '').to_i
    @max_price = params[:max_price].to_s.gsub(/[^\d]/, '').to_i

    # Sorting
    @sort_column = sort_column
    @sort_direction = sort_direction
    
    @habitations = Habitation.left_outer_joins(:address)
                             .order(Arel.sql("habitations.#{@sort_column} #{@sort_direction} NULLS LAST"))
    
    # Text Search
    if @q.present?
      @habitations = @habitations.where(
        "codigo ILIKE :q OR titulo_anuncio ILIKE :q OR descricao_web ILIKE :q OR " \
        "COALESCE(addresses.logradouro, habitations.endereco) ILIKE :q OR " \
        "COALESCE(addresses.bairro, habitations.bairro) ILIKE :q OR " \
        "COALESCE(addresses.cidade, habitations.cidade) ILIKE :q",
        q: "%#{@q}%"
      )
    end
    
    # Standard Filters
    @habitations = @habitations.where(status: @status) if @status.present? && @status != 'Todos'
    @habitations = @habitations.where(categoria: @categoria) if @categoria.present? && @categoria != 'Todas'
    
    # Advanced Filters Application
    @habitations = @habitations.where("COALESCE(addresses.cidade, habitations.cidade) = ?", @cidade) if @cidade.present?
    @habitations = @habitations.where("COALESCE(addresses.bairro, habitations.bairro) ILIKE ?", "%#{@bairro}%") if @bairro.present?
    
    @habitations = @habitations.where("dormitorios_qtd >= ?", @dorms) if @dorms.present? && @dorms.to_i > 0
    @habitations = @habitations.where("suites_qtd >= ?", @suites) if @suites.present? && @suites.to_i > 0
    @habitations = @habitations.where("vagas_qtd >= ?", @vagas) if @vagas.present? && @vagas.to_i > 0

    if @promotion_status == 'with_promo'
      @habitations = @habitations.where(
        "(valor_venda_anterior_cents > valor_venda_cents AND valor_venda_cents > 0) OR valor_promocional_cents > 0"
      )
    elsif @promotion_status == 'without_promo'
      @habitations = @habitations.where(
        "NOT ((valor_venda_anterior_cents > valor_venda_cents AND valor_venda_cents > 0) OR valor_promocional_cents > 0)"
      )
    end

    if @accepts_exchange == '1'
      @habitations = @habitations.where(aceita_permuta_flag: true)
    elsif @accepts_exchange == '0'
      @habitations = @habitations.where(aceita_permuta_flag: false)
    end

    @habitations = @habitations.where(key_location: @key_location) if @key_location.present?

    if @salute_rental_management == '1'
      @habitations = @habitations.where(salute_rental_management_flag: true)
    elsif @salute_rental_management == '0'
      @habitations = @habitations.where(salute_rental_management_flag: false)
    end
    
    if @min_price > 0
      @habitations = @habitations.where("valor_venda_cents >= ? OR valor_locacao_cents >= ?", @min_price * 100, @min_price * 100)
    end
    
    if @max_price > 0
      @habitations = @habitations.where("valor_venda_cents <= ? OR valor_locacao_cents <= ?", @max_price * 100, @max_price * 100)
    end
    
    # Scopes/Pills
    @scope = params[:scope]
    case @scope
    when 'oportunidade' then @habitations = @habitations.opportunity
    when 'frente_mar' then @habitations = @habitations.where(frente_mar_avenida_atlantica_flag: true).or(@habitations.where(vista_frente_mar_flag: true))
    when 'lancamento' then @habitations = @habitations.where(lancamento_flag: true)
    when 'na_planta' then @habitations = @habitations.where("situacao ILIKE ?", "%Planta%")
    when 'mobiliado' then @habitations = @habitations.where(mobiliado_flag: true)
    when 'sacada' then @habitations = @habitations.where(varanda_gourmet_flag: true) # Approximation
    when 'decorado' then @habitations = @habitations.where(decorado_flag: true)
    end

    @habitations = @habitations.paginate(page: params[:page], per_page: 20)
    @page_title = "Gerenciar Imóveis"
    
    # Load filter data
    load_filter_data
  end

  def new
    @habitation = Habitation.new
    @habitation.build_address
    @page_title = "Novo Imóvel"
  end

  def create
    @habitation = Habitation.new(habitation_params)

    if @habitation.save
      redirect_to admin_habitations_path, notice: "Imóvel criado com sucesso."
    else
      load_autocomplete_data
      render :new
    end
  end


  def edit
    @page_title = "Editar Imóvel: #{@habitation.codigo}"
  end

  def update
    if @habitation.update(habitation_params)
      redirect_to admin_habitations_path, notice: "Imóvel atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
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

  private

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
    @constructors = Constructor.select(:id, :name).order(name: :asc)
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
        badges: AttributeOption.where(context: 'habitation', category: 'unique_feature').order(name: :asc).pluck(:name),
        imediacoes_options: AttributeOption.where(context: 'habitation', category: 'imediacoes').order(name: :asc).pluck(:name),
        internal_features: AttributeOption.where(context: 'habitation', category: 'feature').order(name: :asc).pluck(:name),
        external_features: AttributeOption.where(context: 'habitation', category: 'infrastructure').order(name: :asc).pluck(:name)
      }
    end

    @cities = cached[:cities]
    @neighborhoods = cached[:neighborhoods]
    @badges = cached[:badges]
    @imediacoes_options = cached[:imediacoes_options]
    @internal_features = cached[:internal_features]
    @external_features = cached[:external_features]
    @categories = (
      Habitation::CATEGORIES +
      Habitation.where("NULLIF(TRIM(categoria), '') IS NOT NULL AND categoria != '.'").distinct.pluck(:categoria) +
      ["Empreendimento"]
    ).compact.uniq.sort
  end

  def load_filter_data
    @filter_categories = Habitation.where("NULLIF(TRIM(categoria), '') IS NOT NULL AND categoria != '.'")
                                   .distinct.pluck(:categoria).sort
    @filter_cities = Habitation.left_outer_joins(:address)
                               .where("NULLIF(TRIM(COALESCE(addresses.cidade, habitations.cidade)), '') IS NOT NULL AND COALESCE(addresses.cidade, habitations.cidade) != '.'")
                               .distinct
                               .pluck(Arel.sql("COALESCE(addresses.cidade, habitations.cidade)"))
                               .sort
    @filter_statuses = Habitation.where("NULLIF(TRIM(status), '') IS NOT NULL AND status != '.'")
                                 .distinct.pluck(:status).sort
    existing_key_locations = Habitation.where("NULLIF(TRIM(key_location), '') IS NOT NULL")
                                       .distinct
                                       .pluck(:key_location)
                                       .sort
    @filter_key_locations = (Habitation::KEY_LOCATION_OPTIONS + existing_key_locations).uniq
  end

  def habitation_params
    params.require(:habitation).permit(
      :codigo, :slug, :categoria, :status, :situacao, :tipo, :codigo_empreendimento, 
      :nome_empreendimento,
      :dormitorios_qtd, :suites_qtd, :banheiros_qtd, :vagas_qtd, :elevadores_qtd, 
      :area_privativa_m2, :area_total_m2, :area_terreno_m2, :area_util_m2, 
      :valor_venda_formatted, :valor_locacao_formatted, :valor_condominio_formatted, :valor_iptu_formatted, :valor_por_m2_formatted, 
      :descricao_web, :descricao_interna, :titulo_anuncio, :observacoes, 
      :corretor_nome, :corretor_telefone, :corretor_email, :proprietario_codigo,
      :proprietario, :proprietario_celular, :proprietario_telefone_comercial,
      :proprietario_telefone_residencial, :proprietario_email,
      :exibir_no_site_flag, :destaque_web_flag, :lancamento_flag, :aceita_permuta_flag, 
      :aceita_financiamento_flag, :mobiliado_flag, :data_entrega, :status_vista, 
      :meta_title, :meta_description, :meta_keywords, 
      :piscina_flag, :lavabo_flag, :varanda_gourmet_flag, :bloco, :lote,
      :banheiro_social_qtd, :decorado_flag, :aptos_andar, :aptos_edificio,
      :garden_flag, :quadra_mar_flag, :sem_mobilia_flag, 
      :valor_venda_anterior_cents, :valor_venda_anterior_formatted, :valor_total_aluguel_cents, :valor_promocional_formatted, 
      :proprietario, :inscricao_imobiliaria, :descricao_empreendimento,
      :categoria_grupo, :tour_virtual,
      :constructor_id,
      :terceira_avenida_flag, :arriba_flag, :avenida_brasil_flag, :bairro_fazenda_itajai_flag, 
      :balneario_picarras_flag, :barra_flag, :barra_norte_flag, :barra_sul_flag, 
      :cabecudas_flag, :camboriu_flag, :centro_flag, :estaleirinho_flag, 
      :frente_mar_avenida_atlantica_flag, :itajai_flag, :itapema_flag, :nacoes_flag, 
      :pioneiros_flag, :praia_brava_flag, :praia_dos_amores_flag, :vista_frente_mar_flag, 
      :festival_salute_flag, :exibir_no_site_salute_flag, :tem_placa_flag,
      :exclusivo_flag, :ocupacao_status, :estado_conservacao,
      :andar, :ano_construcao, :demi_suites_qtd, :numero_box, 
      :dimensoes_terreno, :topografia, :foto_classificacao, :podcast_url,
      :agenciador, :captador_commission_percentage, :broker_commission_percentage,
      :salute_rental_management_flag, :key_location, :key_location_notes,
      videos: [], plantas: [], fotos_empreendimento: [], photos: [],
      ordered_photo_ids: [], meta_keywords: [],
      caracteristicas: [], infra_estrutura: [], caracteristica_unica: [],
      broker_assignments_attributes: [:id, :admin_user_id, :role, :commission_type, :commission_value, :observations, :_destroy],
      address_attributes: [:id, :tipo_endereco, :logradouro, :numero, :complemento, :bairro, :bairro_comercial, :cidade, :uf, :cep, :pais, :latitude, :longitude, :_destroy, { imediacoes: [] }]
    )
  end
end

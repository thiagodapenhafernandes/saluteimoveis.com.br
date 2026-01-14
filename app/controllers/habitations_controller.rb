class HabitationsController < ApplicationController
  include HabitationCaching
  include ActionView::Helpers::NumberHelper
  before_action :set_habitation, only: [:show]
  
  # GET /habitations
  # GET /imoveis
  def index
    # Handle Target Price (Approximate Search ±20%)
    if params[:target_price].present?
      # Remove non-digits to get raw integer value
      target_value = params[:target_price].to_s.gsub(/\D/, '').to_i
      
      if target_value > 0
        min_price = (target_value * 0.8).to_i
        max_price = (target_value * 1.2).to_i
        
        # Merge calculated range into params for advanced_search
        params[:min_price] = min_price
        params[:max_price] = max_price
      end
    end

    @habitations = Habitation
      .active
      .advanced_search(search_params)
      .includes(:empreendimento)
      .paginate(page: params[:page], per_page: 12)
    
    # SEO page name
    @page_name = 'imoveis'
    
    # Definir meta tags para SEO
    @page_title = build_index_title
    @page_description = build_index_description
    @page_keywords = build_index_keywords
    
    # Cache da página
    cache_index_page
    
    respond_to do |format|
      format.html
      format.json { render json: @habitations.map(&:card_data) }
    end
  end
  
  # GET /buscar-codigo?code=1234
  def search_by_code
    code = params[:code].to_s.strip
    
    if code.blank?
      redirect_to root_path, alert: 'Por favor, informe um código válido.'
      return
    end
    
    property = Habitation.active.find_by(codigo: code)
    
    if property
      redirect_to habitation_path(property), notice: "Imóvel ##{code} encontrado!"
    else
      redirect_to habitations_path(search: code), 
                  alert: "Imóvel com código #{code} não encontrado. Veja outros imóveis disponíveis."
    end
  end
  
  # POST /imoveis/:id/schedule_visit
  def schedule_visit
    @habitation = Habitation.friendly.find(params[:id])
    
    # Enviar webhook com dados do formulário + código do imóvel
    webhook_data = visit_params.to_h.merge(
      property_code: @habitation.codigo,
      property_title: @habitation.display_title,
      property_url: habitation_url(@habitation)
    )
    
    WebhookService.send_form_data('property_visit_form', webhook_data)
    
    redirect_to habitation_path(@habitation), notice: 'Visita agendada com sucesso! Entraremos em contato para confirmar.'
  end
  
  # GET /habitations/autocomplete?q=balneario
  # GET /habitations/autocomplete?q=balneario
  def autocomplete
    term = params[:q].to_s.strip
    results = []

    if term.present?
      # 1. Cidades
      cidades = Habitation.active
                         .where("unaccent(cidade) ILIKE unaccent(?)", "%#{term}%")
                         .distinct
                         .limit(5)
                         .pluck(:cidade)
      
      results += cidades.map { |c| { label: "#{c} (Cidade)", value: c, type: 'cidade' } }

      # 2. Bairros
      bairros = Habitation.active
                          .where("unaccent(bairro) ILIKE unaccent(?)", "%#{term}%")
                          .distinct
                          .limit(5)
                          .pluck(:bairro)
      
      results += bairros.map { |b| { label: "#{b} (Bairro)", value: b, type: 'bairro' } }

      # 3. Empreendimentos
      empreendimentos = Habitation.empreendimentos_publicos
                                  .where("unaccent(nome_empreendimento) ILIKE unaccent(?)", "%#{term}%")
                                  .limit(5)
                                  .select(:nome_empreendimento, :slug)
      
      results += empreendimentos.map do |e| 
        { 
          label: "#{e.nome_empreendimento} (Empreendimento)", 
          value: e.nome_empreendimento, 
          type: 'empreendimento',
          url: habitation_path(e) # URL para redirecionamento direto
        } 
      end
    else
      # Sugestões padrão quando vazio (opcional)
      cidades_populares = Habitation.active.group(:cidade).order('count_all DESC').limit(5).count.keys
      results += cidades_populares.map { |c| { label: c, value: c, type: 'cidade' } }
    end

    render json: results
  rescue => e
    Rails.logger.error "Autocomplete error: #{e.message}"
    render json: []
  end
  
  # GET /imovel/:id
  def show
    # Incrementar contador de visualizações (em background)
    # increment_view_count(@habitation.id)
    
    # Meta tags dinâmicas
    @page_title = @habitation.seo_title
    @page_description = @habitation.seo_description
    @page_keywords = @habitation.seo_keywords
    
    # Image for social sharing (Open Graph)
    if @habitation.all_images.any?
      first_photo = @habitation.all_images.first
      @page_image = first_photo['url'] || first_photo[:url]
    end
    
    # Detectar se é empreendimento e carregar unidades
    if @habitation.empreendimento?
      @is_development_page = true
      @development_units = @habitation.development_units.newest_first
      # Usar template específico para empreendimentos
      render 'empreendimento_show' and return
    end
    
    # Imóveis relacionados (mesma região, quartos e faixa de preço ±20%)
    @related_properties = []
    
    if @habitation.present?
      # Calcular faixa de preço (±20%)
      base_price = @habitation.valor_venda_cents || @habitation.valor_locacao_cents
      
      if base_price && base_price > 0
        min_price = (base_price * 0.8).to_i
        max_price = (base_price * 1.2).to_i
        
        @related_properties = Habitation
          .active
          .with_photos  # Apenas com fotos
          .where(cidade: @habitation.cidade)  # Mesma cidade
          .where(dormitorios_qtd: @habitation.dormitorios_qtd)  # Mesmos quartos
          .where.not(id: @habitation.id)  # Excluir o imóvel atual
          .where(
            "(valor_venda_cents BETWEEN ? AND ?) OR (valor_locacao_cents BETWEEN ? AND ?)",
            min_price, max_price, min_price, max_price
          )
          .newest_first
          .limit(6)
      end
    end
    
    # Cache da página
    cache_show_page(@habitation)
    
    respond_to do |format|
      format.html
      format.json { render json: @habitation.card_data }
    end
  end
  
  private
  
  def set_habitation
    # Tentar encontrar como empreendimento primeiro (sem restrições de preço/status)
    @habitation = Habitation
      .where(exibir_no_site_flag: true)
      .friendly
      .find(params[:id])
    
    # Se não for empreendimento, validar que passa pelos filtros do scope active
    if @habitation && !@habitation.empreendimento?
      # Para imóveis normais, validar que tem fotos e preço
      unless @habitation.pictures.present? && 
             (@habitation.valor_venda_cents.to_i > 0 || @habitation.valor_locacao_cents.to_i > 0)
        raise ActiveRecord::RecordNotFound
      end
    end
    
  rescue ActiveRecord::RecordNotFound
    redirect_to habitations_path, alert: 'Imóvel não encontrado ou indisponível no momento.'
  end
  
  def search_params
    params.permit(
      :transaction_type,
      :category,
      :city,
      :neighborhood,
      :state,
      :min_bedrooms,
      :min_suites,
      :min_bathrooms,
      :min_parking,
      :min_area,
      :max_area,
      :min_price,
      :max_price,
      :target_price,
      :furnished,
      :accepts_exchange,
      :accepts_financing,
      :search,
      :sort,
      characteristics: []
    )
  end
  
  def visit_params
    params.permit(:name, :email, :phone, :preferred_date, :preferred_time, :message)
  end
  
  # SEO OPTIMIZATION - Dynamic & Varied Meta Tags (Style: Conexão Imobiliária)
  def build_index_title
    count = @habitations.total_entries rescue @habitations.count
    city = params[:city].presence || params[:bairro].presence || "Balneário Camboriú"
    category = params[:category].presence || "Imóveis"
    
    # Determine Transaction Context
    transaction_term = case params[:transaction_type]
                       when 'venda' then 'à Venda'
                       when 'aluguel', 'locacao' then 'para Alugar'
                       else ''
                       end

    # Check for specific scenarios
    is_reduced = params[:characteristics]&.include?('opportunity') || 
                 @habitations.any? { |h| h.valor_venda_anterior_cents.to_i > h.valor_venda_cents && h.valor_venda_anterior_cents > 0 }
    
    is_luxury = params[:min_price].to_i > 2_000_000 || params[:quadra_mar] == '1' || params[:frente_mar] == '1'
    
    # Varied Templates (Randomized selection to avoid robotic patterns)
    templates = []
    
    if is_reduced
      templates << "Oportunidade: #{category} com Valor Reduzido em #{city}"
      templates << "Preço Baixo: #{category} em #{city} com Desconto"
      templates << "Ofertas de #{category} em #{city} - Aproveite"
    elsif is_luxury
      templates << "#{category} de Alto Padrão em #{city} - Exclusividade"
      templates << "Luxo e Sofisticação: #{category} em #{city}"
      templates << "Os Melhores #{category} em #{city} estão Aqui"
    else
      # Standard variations
      if transaction_term.present?
        templates << "#{category} #{transaction_term} em #{city}"
        templates << "Encontre seu #{category} #{transaction_term} em #{city}"
        templates << "Busca de #{category} #{transaction_term} na região de #{city}"
        templates << "#{category} em #{city} - Veja Opções #{transaction_term}"
      else
        templates << "#{category} em #{city} - Confira as Novidades"
        templates << "Imobiliária em #{city} - Veja #{category}"
        templates << "Seleção de #{category} em #{city} e Região"
      end
    end
    
    # Select a template deterministically based on page content to avoid SEO flickering
    # Using params hash ensures the same search always yields the same title
    seed = params.to_s.chars.sum(&:ord)
    selected_title = templates[seed % templates.length]
    
    # Append minimal suffix
    "#{selected_title} (#{count}) | Salute"
  end
  
  def build_index_description
    city = params[:city].presence || "Balneário Camboriú"
    category = params[:category].presence || "imóveis"
    
    # Varied Hooks/Intros
    intros = [
      "Procurando por #{category.downcase} em #{city}?",
      "Descubra as melhores opções de #{category.downcase} em #{city}.",
      "A Salute Imóveis selecionou #{category.downcase} incríveis em #{city} para você.",
      "Não feche negócio antes de ver estes #{category.downcase} em #{city}.",
      "Seu sonho de morar em #{city} comece aqui com estes #{category.downcase}."
    ]
    
    # Varied CTAs/Closings
    ctas = [
      "Agende sua visita hoje mesmo!",
      "Confira fotos e detalhes exclusivos.",
      "Fale com nossos corretores especialistas.",
      "Acesse e veja todas as oportunidades.",
      "Venha conhecer seu novo lar."
    ]
    
    # Select deterministically
    seed = params.to_s.chars.sum(&:ord)
    intro = intros[seed % intros.length]
    cta = ctas[(seed + 1) % ctas.length]
    
    # Features List
    features = []
    features << "frente mar" if params[:vista_frente_mar_flag] == '1'
    features << "mobiliado" if params[:mobiliado_flag] == '1'
    features << "com valor reduzido" if @habitations.any? { |h| h.valor_venda_anterior_cents.to_i > h.valor_venda_cents }
    
    feature_text = features.any? ? " Opções com #{features.join(', ')}." : ""
    
    "#{intro}#{feature_text} Temos diversas opções à sua espera. #{cta}"
  end
  
  def build_index_keywords
    keywords = Set.new(['imóveis', 'imobiliária', 'balneário camboriú', 'salute imóveis'])
    
    # Transaction
    keywords << 'venda' if params[:transaction_type] == 'venda'
    keywords << 'aluguel' << 'locação' if params[:transaction_type] =~ /aluguel|locacao/
    
    # Category
    keywords << params[:category].downcase if params[:category].present?
    
    # Location (critical keywords)
    keywords << params[:city].downcase if params[:city].present?
    keywords << params[:bairro].downcase if params[:bairro].present?
    keywords << 'praia brava' << 'centro' << 'barra sul' # Common searches
    
    # High-value characteristics
    keywords << 'frente mar' << 'vista mar' if params[:vista_frente_mar_flag] == '1'
    keywords << 'piscina' if params[:piscina_flag] == '1'
    keywords << 'mobiliado' if params[:mobiliado_flag] == '1'
    keywords << 'cobertura' if params[:category] == 'Cobertura'
    keywords << 'apartamento alto padrão' if params[:min_price].to_i > 1_000_000
    
    # Valor reduzido/Oportunidade
    if @habitations.any? { |h| h.valor_venda_anterior_cents.to_i > h.valor_venda_cents }
      keywords << 'valor reduzido' << 'promoção' << 'oportunidade' << 'desconto'
    end
    
    keywords.to_a.join(', ')
  end
end

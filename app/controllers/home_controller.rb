class HomeController < ApplicationController
  def index
    # Load active home sections
    @home_sections = Rails.cache.fetch("home_sections_active_v2", expires_in: 1.hour) do
      HomeSection.active.to_a
    end
    @sections_map = @home_sections.index_by(&:section_type)
    
    # Carrossel de Destaques - 12 imóveis (only if section is active)
    if @sections_map['featured_properties']&.active?
      @featured_properties = Habitation.active.featured.newest_first.limit(12)
    end
    
    # Carrossel de Oportunidades - 12 imóveis com desconto (only if section is active)
    if @sections_map['opportunities']&.active?
      @opportunity_properties = Habitation.active
        .where('valor_venda_anterior_cents > valor_venda_cents OR valor_promocional_cents > 0')
        .newest_first
        .limit(12)
    end
    
    # Carrossel de Empreendimentos (only if section is active)
    if @sections_map['developments']&.active?
      all_developments = Habitation
        .empreendimentos_publicos
        .where.not(codigo: nil)
        .newest_first
        .limit(20)
      
      # Filtrar duplicados por codigo
      seen_codes = Set.new
      @recent_properties = all_developments.select do |dev|
        next false if seen_codes.include?(dev.codigo)
        seen_codes.add(dev.codigo)
        true
      end.first(12)

      # Pre-calculate unit counts for development carousel to avoid N+1
      dev_codes = @recent_properties.map(&:codigo).compact
      @dev_unit_counts = Habitation.where.not(codigo_empreendimento: nil)
                                   .where(codigo_empreendimento: dev_codes)
                                   .group(:codigo_empreendimento)
                                   .count
    end
    
    # Imóveis para Locação (only if section is active)
    if @sections_map['rentals']&.active?
      @rental_properties = Habitation.active.for_rent.newest_first.limit(6)
    end
    
    # Tipos de imóveis disponíveis (para o formulário de busca) - CACHED
    @property_types = Rails.cache.fetch("home_property_types_v5", expires_in: 12.hours) do
      Habitation.where(exibir_no_site_flag: true).distinct.pluck(:categoria).compact.sort
    end
    
    # Home settings
    @home_setting = HomeSetting.instance
    
    # SEO
    @page_name = 'home'
    @page_title = 'Salute Imóveis | Encontre seu Imóvel Ideal'
    @page_description = 'Os melhores imóveis para venda e locação. Apartamentos, casas, terrenos e mais.'
    
    # Cache da página (Browser)
    expires_in 15.minutes, public: true
  end
  
  def sobre
    @page_name = 'sobre'
    @page_title = 'Sobre Nós | Salute Imóveis'
    @page_description = 'Conheça a Salute Imóveis, sua imobiliária de confiança.'
  end
  
  def contato
    @page_name = 'contato'
    @page_title = 'Contato | Salute Imóveis'
    @page_description = 'Entre em contato com a Salute Imóveis. Estamos prontos para ajudar você.'
  end
end

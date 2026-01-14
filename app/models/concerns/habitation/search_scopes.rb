module Habitation::SearchScopes
  extend ActiveSupport::Concern
  
  included do
    # Scopes básicos de visibilidade
    # IMPORTANTE: Apenas imóveis com status válido para exibição pública
    scope :active, -> { 
      where(exibir_no_site_flag: true)
        .where(status: ['Venda', 'Aluguel', 'Venda e Aluguel'])
        .with_photos
        .with_price 
    }
    scope :featured, -> { where(destaque_web_flag: true) }
    scope :lancamento, -> { where("lancamento_flag = true OR unaccent(caracteristica_unica) ILIKE unaccent('%lançamento%')") }
    scope :na_planta, -> { where("unaccent(caracteristica_unica) ILIKE unaccent('%planta%')") }
    scope :pronto, -> { where("unaccent(caracteristica_unica) ILIKE unaccent('%pronto%')") }
    scope :em_construcao, -> { where("unaccent(caracteristica_unica) ILIKE unaccent('%construção%')") }
    
    # Scope para imóveis com fotos (verifica se é array e tem elementos)
    scope :with_photos, -> { where("jsonb_typeof(pictures) = 'array' AND jsonb_array_length(pictures) > 0") }
    
    # Scope para imóveis com preço (venda ou locação)
    scope :with_price, -> { where("valor_venda_cents > 0 OR valor_locacao_cents > 0") }
    
    # Scopes por tipo de transação (baseado em preço)
    scope :for_sale, -> { where("valor_venda_cents > 0") }
    scope :for_rent, -> { where("valor_locacao_cents > 0") }
    
    # Scopes por categoria (com unaccent)
    scope :by_category, ->(category) { 
      if category.is_a?(Array)
        clean = category.reject(&:blank?)
        if clean.any?
          where("unaccent(categoria) IN (SELECT unaccent(n) FROM unnest(ARRAY[?]) AS n)", clean)
        else
          all
        end
      elsif category.present?
        where("unaccent(categoria) ILIKE unaccent(?)", category)
      else
        all
      end
    }
    scope :apartamentos, -> { where("unaccent(categoria) ILIKE unaccent(?)", "%apartamento%") }
    scope :casas, -> { where("unaccent(categoria) ILIKE unaccent(?)", "%casa%") }
    scope :terrenos, -> { where("unaccent(categoria) ILIKE unaccent(?)", "%terreno%") }
    scope :comerciais, -> { where("unaccent(categoria) ILIKE unaccent(?)", "%comercial%") }
    
    # Scopes por localização (com unaccent e busca flexível)
    scope :by_city, ->(city) { 
      if city.is_a?(Array)
        clean = city.reject(&:blank?)
        if clean.any?
          where("unaccent(cidade) IN (SELECT unaccent(n) FROM unnest(ARRAY[?]) AS n)", clean)
        else
          all
        end
      elsif city.present?
        where("unaccent(cidade) ILIKE unaccent(?)", "%#{city}%")
      else
        all
      end
    }
    scope :by_neighborhood, ->(neighborhood) { 
      if neighborhood.is_a?(Array)
        neighborhood_clean = neighborhood.reject(&:blank?)
        if neighborhood_clean.any?
          where("unaccent(bairro) IN (SELECT unaccent(n) FROM unnest(ARRAY[?]) AS n)", neighborhood_clean)
        else
          all
        end
      elsif neighborhood.present?
        where("unaccent(bairro) ILIKE unaccent(?)", "%#{neighborhood}%")
      else
        all
      end
    }
    scope :by_state, ->(state) { where(uf: state) if state.present? }
    
    # Scopes por características
    scope :with_min_bedrooms, ->(count) { where("dormitorios_qtd >= ?", count) if count.present? }
    scope :with_min_suites, ->(count) { where("suites_qtd >= ?", count) if count.present? }
    scope :with_min_bathrooms, ->(count) { where("banheiros_qtd >= ?", count) if count.present? }
    scope :with_min_parking, ->(count) { where("vagas_qtd >= ?", count) if count.present? }
    
    # Scopes por área
    scope :with_min_area, ->(area) { where("area_total_m2 >= ?", area) if area.present? }
    scope :with_max_area, ->(area) { where("area_total_m2 <= ?", area) if area.present? }
    scope :by_area_range, ->(min, max) {
      query = all
      query = query.where("area_total_m2 >= ?", min) if min.present?
      query = query.where("area_total_m2 <= ?", max) if max.present?
      query
    }
    
    # Scopes por preço
    scope :with_min_price, ->(price) {
      return unless price.present?
      # Remove pontos de formatação antes de converter
      price_cents = price.to_s.gsub(/[^\d]/, '').to_i * 100
      where("valor_venda_cents >= ? OR valor_locacao_cents >= ?", price_cents, price_cents)
    }
    scope :with_max_price, ->(price) {
      return unless price.present?
      # Remove pontos de formatação antes de converter
      price_cents = price.to_s.gsub(/[^\d]/, '').to_i * 100
      where("valor_venda_cents <= ? OR valor_locacao_cents <= ?", price_cents, price_cents)
    }
    scope :by_price_range, ->(min, max) {
      query = all
      if min.present?
        # Remove pontos de formatação antes de converter
        min_cents = min.to_s.gsub(/[^\d]/, '').to_i * 100
        query = query.where("valor_venda_cents >= ? OR valor_locacao_cents >= ?", min_cents, min_cents)
      end
      if max.present?
        # Remove pontos de formatação antes de converter
        max_cents = max.to_s.gsub(/[^\d]/, '').to_i * 100
        query = query.where("valor_venda_cents <= ? OR valor_locacao_cents <= ?", max_cents, max_cents)
      end
      query
    }
    
    # Scopes por flags
    scope :mobiliado, -> { where("mobiliado_flag = true OR caracteristicas ? 'mobiliado'") }
    scope :aceita_permuta, -> { where(aceita_permuta_flag: true) }
    scope :aceita_financiamento, -> { where(aceita_financiamento_flag: true) }
    
    # Scope para busca de texto robusta (com unaccent)
    scope :search_text, ->(query) {
      if query.present?
        sanitized = query.strip
        where(
          "unaccent(titulo_anuncio) ILIKE unaccent(:q) OR " \
          "unaccent(descricao_web) ILIKE unaccent(:q) OR " \
          "unaccent(endereco) ILIKE unaccent(:q) OR " \
          "unaccent(bairro) ILIKE unaccent(:q) OR " \
          "unaccent(cidade) ILIKE unaccent(:q) OR " \
          "unaccent(nome_empreendimento) ILIKE unaccent(:q) OR " \
          "unaccent(caracteristica_unica) ILIKE unaccent(:q) OR " \
          "codigo ILIKE :q",
          q: "%#{sanitized}%"
        )
      end
    }
    
    # Busca em características JSONB (frente mar, quadra mar, varanda, etc)
    scope :search_characteristics, ->(query) {
      if query.present?
        sanitized = query.strip.downcase
        where(
          "EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE unaccent(?))",
          "%#{sanitized}%"
        )
      end
    }
    
    # Busca em infraestrutura JSONB
    scope :search_infrastructure, ->(query) {
      if query.present?
        sanitized = query.strip.downcase
        where(
          "jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) WHERE unaccent(lower(value)) ILIKE unaccent(?))",
          "%#{sanitized}%"
        )
      end
    }
    
    # Características específicas comuns
    # Frente Mar = Avenida beira-mar (primeira linha)
    scope :frente_mar, lambda {
      where(
        "frente_mar_avenida_atlantica_flag = true OR " \
        "vista_frente_mar_flag = true OR " \
        "unaccent(descricao_web) ILIKE unaccent('%frente%mar%')"
      )
    }
    
    # Vista Mar = Vista para o mar (qualquer posição)
    scope :vista_mar, lambda {
      where("caracteristicas ? 'vista_mar' OR vista_mar_flag = true")
    }

    # Quadra Mar
    scope :quadra_mar, lambda {
      where("quadra_mar_flag = true OR caracteristicas ? 'quadra_mar'")
    }

    # Sacada
    scope :sacada, lambda {
      where("caracteristicas ? 'sacada' OR varanda_gourmet_flag = true")
    }

    # Decorado
    scope :decorado, lambda {
      where("decorado_flag = true OR caracteristicas ? 'decorado'")
    }

    # Garden
    scope :garden, lambda {
      where(garden_flag: true)
    }

    # Festival Salute
    scope :festival_salute, lambda {
      where(festival_salute_flag: true)
    }

    # Exibir no Site Salute
    scope :exibir_site_salute, lambda {
      where(exibir_no_site_salute_flag: true)
    }

    # Oportunidade (Preço Reduzido)
    scope :opportunity, lambda {
      where(
        "(valor_venda_anterior_cents > valor_venda_cents AND valor_venda_cents > 0) OR " \
        "(valor_promocional_cents > 0)"
      )
    }
    
    scope :quadra_mar, -> { 
      where("quadra_mar_flag = true OR caracteristicas ? 'quadramar'")
    }
    
    scope :varanda, -> { 
      where("caracteristicas->> 'varanda' = 'true' OR " \
            "varanda_gourmet_flag = true OR " \
            "EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%varanda%')")
    }
    
    # Outras características via JSONB
    scope :churrasqueira, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%churrasqueira%') OR " \
            "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) WHERE unaccent(lower(value)) ILIKE '%churrasqueira%'))")
    }
    
    scope :sacada, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%sacada%')")
    }
    
    scope :decorado, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%decorado%')")
    }
    
    scope :vista_mar, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%vista%mar%')")
    }
    
    scope :closet, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%closet%')")
    }
    
    scope :semi_mobiliado, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%semi%mobiliado%')")
    }
    
    scope :lavabo, -> {
      where("lavabo_flag = true OR " \
            "EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%lavabo%')")
    }
    
    scope :lavanderia, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%lavanderia%')")
    }
    
    scope :hidromassagem, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%hidromassagem%') OR " \
            "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) WHERE unaccent(lower(value)) ILIKE '%hidromassagem%'))")
    }
    
    scope :piscina, -> {
      where("piscina_flag = true OR " \
            "EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%piscina%') OR " \
            "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) WHERE unaccent(lower(value)) ILIKE '%piscina%'))")
    }
    
    scope :sala_estar, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%sala%estar%')")
    }
    
    scope :sala_jantar, -> {
      where("EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE '%sala%jantar%')")
    }
    
    # Scopes de ordenação
    scope :newest_first, -> { order(data_atualizacao_crm: :desc, created_at: :desc) }
    scope :oldest_first, -> { order(data_atualizacao_crm: :asc, created_at: :asc) }
    scope :price_asc, -> { order(Arel.sql("COALESCE(valor_venda_cents, valor_locacao_cents) ASC")) }
    scope :price_desc, -> { order(Arel.sql("COALESCE(valor_venda_cents, valor_locacao_cents) DESC")) }
    scope :area_asc, -> { order(area_total_m2: :asc) }
    scope :area_desc, -> { order(area_total_m2: :desc) }
    
    # Scope para empreendimentos
    scope :empreendimentos, -> { where(tipo: 'Empreendimento') }

    # Empreendimentos publicos com foto e pelo menos 1 unidade disponivel
    scope :empreendimentos_publicos, -> {
      empreendimentos
        .where(exibir_no_site_flag: true)
        .with_development_images
        .with_available_units
    }

    scope :with_development_images, -> {
      where(
        "(jsonb_typeof(fotos_empreendimento) = 'array' AND jsonb_array_length(fotos_empreendimento) > 0) OR " \
        "(jsonb_typeof(pictures) = 'array' AND jsonb_array_length(pictures) > 0)"
      )
    }

    scope :with_available_units, -> {
      where(
        "EXISTS (" \
        "SELECT 1 FROM habitations units " \
        "WHERE units.codigo_empreendimento = habitations.codigo " \
        "AND units.exibir_no_site_flag = TRUE " \
        "AND units.status IN ('Venda', 'Aluguel', 'Venda e Aluguel') " \
        "AND (units.valor_venda_cents > 0 OR units.valor_locacao_cents > 0) " \
        "AND jsonb_typeof(units.pictures) = 'array' " \
        "AND jsonb_array_length(units.pictures) > 0" \
        ")"
      )
    }
    scope :unidades, -> { where.not(codigo_empreendimento: nil) }
    scope :imoveis_individuais, -> { where(codigo_empreendimento: nil, tipo: 'Unitário').or(where(tipo: nil)) }
  end
  
  class_methods do
    # Busca avançada SUPER DINÂMICA combinando múltiplos filtros
    def advanced_search(params = {})
      params = params.to_h.with_indifferent_access
      query = active.with_photos  # Apenas imóveis com fotos
      
      # Tipo de transação
      query = query.for_sale if params[:transaction_type] == 'venda'
      query = query.for_rent if params[:transaction_type] == 'aluguel' || params[:transaction_type] == 'locacao'
      
      # Categoria
      query = query.by_category(params[:category]) if params[:category].present?
      
      # Localização (busca flexível - cidade OU bairro)
      if params[:city].present?
        if params[:city].is_a?(Array)
          query = query.by_city(params[:city])
        else
          city_term = params[:city].to_s.strip
          query = query.where(
            "unaccent(cidade) ILIKE unaccent(:term) OR unaccent(bairro) ILIKE unaccent(:term) OR unaccent(nome_empreendimento) ILIKE unaccent(:term)",
            term: "%#{city_term}%"
          )
        end
      end
      
      if params[:neighborhood].present?
        query = query.by_neighborhood(params[:neighborhood])
      end
      query = query.by_state(params[:state]) if params[:state].present?
      
      # Características numéricas
      query = query.with_min_bedrooms(params[:min_bedrooms]) if params[:min_bedrooms].present?
      query = query.with_min_suites(params[:min_suites]) if params[:min_suites].present?
      query = query.with_min_bathrooms(params[:min_bathrooms]) if params[:min_bathrooms].present?
      query = query.with_min_parking(params[:min_parking]) if params[:min_parking].present?
      
      # Área
      query = query.by_area_range(params[:min_area], params[:max_area]) if params[:min_area].present? || params[:max_area].present?
      
      # Característica Única (Badge Match)
      if params[:caracteristica_unica].present?
        query = query.where("unaccent(caracteristica_unica) ILIKE unaccent(?)", "%#{params[:caracteristica_unica]}%")
      end

      # Preço Target (Range +/- 20%)
      if params[:target_price].present?
        target_value = params[:target_price].to_s.gsub(/\D/, '').to_i
        if target_value > 0
          min_price = (target_value * 0.8).to_i
          max_price = (target_value * 1.2).to_i
          
          if params[:transaction_type] == 'aluguel'
            query = query.where("valor_locacao_cents BETWEEN ? AND ?", min_price * 100, max_price * 100)
          else
            query = query.where("valor_venda_cents BETWEEN ? AND ?", min_price * 100, max_price * 100)
          end
        end
      end

      # Preço (baseado no tipo de transação)
      if params[:min_price].present? || params[:max_price].present?
        min_cents = params[:min_price].present? ? params[:min_price].to_s.gsub(/[^\d]/, '').to_i * 100 : 0
        max_cents = params[:max_price].present? ? params[:max_price].to_s.gsub(/[^\d]/, '').to_i * 100 : Float::INFINITY
        
        # Se tem tipo de transação específico, filtra apenas esse
        if params[:transaction_type] == 'venda'
          query = query.where("valor_venda_cents BETWEEN ? AND ?", min_cents, max_cents) if min_cents > 0 || max_cents < Float::INFINITY
        elsif params[:transaction_type] == 'aluguel'
          query = query.where("valor_locacao_cents BETWEEN ? AND ?", min_cents, max_cents) if min_cents > 0 || max_cents < Float::INFINITY
        else
          # Se não especificou tipo, busca em ambos (venda OU locação dentro do range)
          if min_cents > 0 && max_cents < Float::INFINITY
            query = query.where(
              "(valor_venda_cents BETWEEN ? AND ?) OR (valor_locacao_cents BETWEEN ? AND ?)",
              min_cents, max_cents, min_cents, max_cents
            )
          elsif min_cents > 0
            query = query.where("valor_venda_cents >= ? OR valor_locacao_cents >= ?", min_cents, min_cents)
          elsif max_cents < Float::INFINITY
            query = query.where("valor_venda_cents <= ? OR valor_locacao_cents <= ?", max_cents, max_cents)
          end
        end
      end
      
      # Flags
      query = query.mobiliado if params[:furnished] == '1' || params[:furnished] == true
      query = query.aceita_permuta if params[:accepts_exchange] == '1' || params[:accepts_exchange] == true
      query = query.aceita_financiamento if params[:accepts_financing] == '1' || params[:accepts_financing] == true
      
      # Características específicas
      query = query.frente_mar if params[:frente_mar] == '1' || params[:frente_mar] == true
      query = query.quadra_mar if params[:quadra_mar] == '1' || params[:quadra_mar] == true
      query = query.varanda if params[:varanda] == '1' || params[:varanda] == true
      
      # Características via array (agora com lógica OU para ser aditivo)
      if params[:characteristics].present?
        characteristics = params[:characteristics].is_a?(Array) ? params[:characteristics] : [params[:characteristics]]
        
        # Criamos um sub-query que será unido por OR
        char_conditions = Habitation.none
        
        characteristics.each do |char|
          case char.to_s
          when 'featured' then char_conditions = char_conditions.or(Habitation.featured)
          when 'frente_mar' then char_conditions = char_conditions.or(Habitation.frente_mar)
          when 'quadra_mar' then char_conditions = char_conditions.or(Habitation.quadra_mar)
          when 'vista_mar' then char_conditions = char_conditions.or(Habitation.vista_mar)
          when 'churrasqueira' then char_conditions = char_conditions.or(Habitation.churrasqueira)
          when 'mobiliado' then char_conditions = char_conditions.or(Habitation.mobiliado)
          when 'sacada' then char_conditions = char_conditions.or(Habitation.sacada)
          when 'decorado' then char_conditions = char_conditions.or(Habitation.decorado)
          when 'closet' then char_conditions = char_conditions.or(Habitation.closet)
          when 'semi_mobiliado' then char_conditions = char_conditions.or(Habitation.semi_mobiliado)
          when 'lavabo' then char_conditions = char_conditions.or(Habitation.lavabo)
          when 'lavanderia' then char_conditions = char_conditions.or(Habitation.lavanderia)
          when 'hidromassagem' then char_conditions = char_conditions.or(Habitation.hidromassagem)
          when 'piscina' then char_conditions = char_conditions.or(Habitation.piscina)
          when 'sala_estar' then char_conditions = char_conditions.or(Habitation.sala_estar)
          when 'sala_jantar' then char_conditions = char_conditions.or(Habitation.sala_jantar)
          when 'varanda' then char_conditions = char_conditions.or(Habitation.varanda)
          when 'lancamento_flag' then char_conditions = char_conditions.or(Habitation.lancamento)
          when 'aceita_permuta_flag' then char_conditions = char_conditions.or(Habitation.aceita_permuta)
          when 'aceita_financiamento_flag' then char_conditions = char_conditions.or(Habitation.aceita_financiamento)
          when 'garden_flag' then char_conditions = char_conditions.or(Habitation.garden)
          when 'festival_salute_flag' then char_conditions = char_conditions.or(Habitation.festival_salute)
          when 'exibir_no_site_salute_flag' then char_conditions = char_conditions.or(Habitation.exibir_site_salute)
          when 'opportunity' then char_conditions = char_conditions.or(Habitation.opportunity)
          when 'na_planta' then char_conditions = char_conditions.or(Habitation.na_planta)
          when 'lancamento' then char_conditions = char_conditions.or(Habitation.lancamento)
          when 'pronto' then char_conditions = char_conditions.or(Habitation.pronto)
          when 'em_construcao' then char_conditions = char_conditions.or(Habitation.em_construcao)
          end
        end
        
        # Aplicamos o grupo de ORs à query principal via subseleção de IDs
        query = query.where(id: char_conditions.select(:id)) if characteristics.any?
      end
      
      # Busca textual geral (título, descrição, endereço, código)
      if params[:search].present?
        search_term = params[:search].strip
        
        # Busca em campos principais
        query = query.where(
          "unaccent(titulo_anuncio) ILIKE unaccent(:q) OR " \
          "unaccent(descricao_web) ILIKE unaccent(:q) OR " \
          "unaccent(endereco) ILIKE unaccent(:q) OR " \
          "unaccent(bairro) ILIKE unaccent(:q) OR " \
          "unaccent(cidade) ILIKE unaccent(:q) OR " \
          "unaccent(nome_empreendimento) ILIKE unaccent(:q) OR " \
          "codigo ILIKE :q OR " \
          "EXISTS (SELECT 1 FROM jsonb_each_text(caracteristicas) WHERE unaccent(lower(value)) ILIKE unaccent(:q)) OR " \
          "(jsonb_typeof(infra_estrutura) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(infra_estrutura) WHERE unaccent(lower(value)) ILIKE unaccent(:q)))",
          q: "%#{search_term}%"
        )
      end
      
      # Ordenação
      query = apply_sorting(query, params[:sort])
      
      query
    end
    
    # Aplica ordenação baseada em parâmetro
    def apply_sorting(query, sort_param)
      case sort_param.to_s
      when 'price_asc'
        query.price_asc
      when 'price_desc'
        query.price_desc
      when 'area_asc'
        query.area_asc
      when 'area_desc'
        query.area_desc
      when 'oldest'
        query.oldest_first
      else
        query.newest_first
      end
    end
  end
end

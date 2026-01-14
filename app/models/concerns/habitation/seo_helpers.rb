module Habitation::SeoHelpers
  extend ActiveSupport::Concern
  
  # Retorna o título SEO otimizado
  def seo_title
    if meta_title.present?
      meta_title
    else
      generate_seo_title
    end
  end
  
  # Retorna a descrição SEO otimizada
  def seo_description
    if meta_description.present?
      meta_description.to_plain_text
    else
      generate_seo_description
    end
  end
  
  # Retorna keywords SEO
  def seo_keywords
    if meta_keywords.present?
      meta_keywords
    else
      generate_seo_keywords
    end
  end
  
  # Retorna dados estruturados para Schema.org (JSON-LD)
  def structured_data
    {
      '@context': 'https://schema.org',
      '@type': 'RealEstateListing',
      name: display_title,
      description: seo_description,
      url: canonical_url,
      identifier: codigo,
      image: image_urls.presence || [primary_image_url].compact,
      address: address_structured_data,
      geo: geo_structured_data,
      floorSize: floor_size_data,
      numberOfRooms: dormitorios_qtd,
      numberOfBathroomsTotal: banheiros_qtd,
      petsAllowed: 'UnknownPermitType',
      offers: offer_structured_data
    }.compact
  end
  
  # URL canônica para SEO
  def canonical_url
    "#{ENV.fetch('APP_HOST', 'https://saluteimoveis.com')}/imovel/#{slug}"
  end
  
  # Open Graph tags
  def og_tags
    {
      'og:type' => 'product',
      'og:title' => seo_title,
      'og:description' => seo_description,
      'og:url' => canonical_url,
      'og:image' => primary_image_url,
      'og:site_name' => 'Salute Imóveis',
      'og:locale' => 'pt_BR'
    }.compact
  end
  
  # Twitter Card tags
  def twitter_tags
    {
      'twitter:card' => 'summary_large_image',
      'twitter:title' => seo_title,
      'twitter:description' => seo_description,
      'twitter:image' => primary_image_url
    }.compact
  end
  
  private
  
  def generate_seo_title
    parts = []
    
    # Categoria + características
    if categoria.present?
      parts << categoria
      parts << "#{dormitorios_qtd} dormitórios" if dormitorios_qtd.to_i > 0
    end
    
    # Localização
    if bairro.present? && cidade.present?
      parts << "no #{bairro}"
      parts << cidade
    elsif cidade.present?
      parts << "em #{cidade}"
    end
    
    # Tipo de transação
    parts << "para #{tipo_transacao}"
    
    # Adicionar Salute Imóveis
    title = parts.join(' ')
    "#{title} | Salute Imóveis"
  end
  
  def generate_seo_description
    parts = []
    
    # Descrição base
    if categoria.present?
      parts << "#{categoria} para #{tipo_transacao&.downcase}"
    end
    
    # Características
    features = []
    features << "#{dormitorios_qtd} dormitórios" if dormitorios_qtd.to_i > 0
    features << "#{suites_qtd} suítes" if suites_qtd.to_i > 0
    features << "#{vagas_qtd} vagas" if vagas_qtd.to_i > 0
    features << "#{area_total_m2.to_i}m²" if area_total_m2.to_f > 0
    
    parts << "com #{features.join(', ')}" if features.any?
    
    # Localização
    if bairro.present? && cidade.present?
      parts << "localizado no #{bairro}, #{cidade}"
    elsif cidade.present?
      parts << "em #{cidade}"
    end
    
    # Preço
    if preco_principal != 'Sob Consulta'
      parts << "por #{preco_principal}"
    end
    
    # Adicionar call to action
    parts << "Confira fotos, vídeos e mais detalhes!"
    
    parts.join(' ')
  end
  
  def generate_seo_keywords
    keywords = []
    
    # Categoria e tipo
    keywords << categoria if categoria.present?
    keywords << tipo_transacao if tipo_transacao.present?
    
    # Localização
    keywords << cidade if cidade.present?
    keywords << bairro if bairro.present?
    keywords << uf if uf.present?
    
    # Características
    keywords << "#{dormitorios_qtd} dormitórios" if dormitorios_qtd.to_i > 0
    keywords << "#{suites_qtd} suítes" if suites_qtd.to_i > 0
    keywords << "#{vagas_qtd} vagas" if vagas_qtd.to_i > 0
    
    # Marca
    keywords << "Salute Imóveis"
    keywords << "Imobiliária"
    
    keywords.join(', ')
  end
  
  def address_structured_data
    return nil unless cidade.present?
    
    {
      '@type': 'PostalAddress',
      streetAddress: [tipo_endereco, endereco, numero].compact.join(' '),
      addressLocality: bairro,
      addressRegion: cidade,
      addressCountry: 'BR',
      postalCode: cep
    }.compact
  end
  
  def geo_structured_data
    return nil unless latitude.present? && longitude.present?
    
    {
      '@type': 'GeoCoordinates',
      latitude: latitude.to_f,
      longitude: longitude.to_f
    }
  end
  
  def floor_size_data
    return nil unless area_total_m2.present?
    
    {
      '@type': 'QuantitativeValue',
      value: area_total_m2.to_f,
      unitCode: 'MTK' # Square Meter
    }
  end
  
  def offer_structured_data
    price_cents = status&.downcase&.include?('venda') ? valor_venda_cents : valor_locacao_cents
    return nil unless price_cents.to_i > 0
    
    {
      '@type': 'Offer',
      price: (price_cents.to_f / 100.0).round(2),
      priceCurrency: 'BRL',
      availability: 'https://schema.org/InStock',
      url: canonical_url
    }
  end
end

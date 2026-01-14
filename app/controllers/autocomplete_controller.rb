class AutocompleteController < ApplicationController
  def locations
    query = params[:query].to_s.strip
    
    # Se query vazia, retornar localizações populares
    if query.blank?
      popular = popular_locations
      return render json: popular
    end
    
    # Buscar cidades, bairros e empreendimentos
    results = []
    
    # Cidades (usando unaccent para ignorar acentos)
    cities = Habitation.active
      .where("unaccent(cidade) ILIKE unaccent(?)", "%#{query}%")
      .select(:cidade)
      .distinct
      .limit(5)
      .pluck(:cidade)
      .compact
      .map { |city| { type: 'Cidade', value: city, label: city } }
    
    # Bairros com cidade (usando unaccent)
    neighborhoods = Habitation.active
      .where("unaccent(bairro) ILIKE unaccent(?) OR unaccent(cidade) ILIKE unaccent(?)", "%#{query}%", "%#{query}%")
      .select(:bairro, :cidade)
      .distinct
      .limit(5)
      .map { |h| { type: 'Bairro', value: h.bairro, label: "#{h.bairro} - #{h.cidade}" } }
      .compact
    
    # Empreendimentos (usando unaccent)
    developments = Habitation.empreendimentos_publicos
      .where("unaccent(nome_empreendimento) ILIKE unaccent(?)", "%#{query}%")
      .where.not(nome_empreendimento: nil)
      .select(:nome_empreendimento, :cidade)
      .distinct
      .limit(5)
      .map { |h| { type: 'Empreendimento', value: h.nome_empreendimento, label: "#{h.nome_empreendimento} - #{h.cidade}" } }
    
    results = cities + neighborhoods + developments
    
    render json: results.uniq.take(10)
  end
  
  private
  
  def popular_locations
    # Retornar as cidades/bairros com mais imóveis
    popular_cities = Habitation.active
      .group(:cidade)
      .order('count_all DESC')
      .limit(5)
      .count
      .keys
      .map { |city| { type: 'Cidade', value: city, label: city } }
    
    popular_neighborhoods = Habitation.active
      .where.not(bairro: nil)
      .group(:bairro, :cidade)
      .order('count_all DESC')
      .limit(5)
      .count
      .keys
      .map { |bairro, cidade| { type: 'Bairro', value: bairro, label: "#{bairro} - #{cidade}" } }
    
    (popular_cities + popular_neighborhoods).take(8)
  end
end

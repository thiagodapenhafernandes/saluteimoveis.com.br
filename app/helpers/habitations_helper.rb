module HabitationsHelper
  # Características disponíveis para filtros
  CHARACTERISTICS = {
    'lancamento' => { label: 'Lançamento', icon: 'bi-stars' },
    'na_planta' => { label: 'Na Planta', icon: 'bi-map' },
    'pronto' => { label: 'Pronto Para Morar', icon: 'bi-check-all' },
    'frente_mar' => { label: 'Frente Mar', icon: 'bi-water' },
    'quadra_mar' => { label: 'Quadra Mar', icon: 'bi-building' },
    'vista_mar' => { label: 'Vista Mar', icon: 'bi-eye' },
    'churrasqueira' => { label: 'Churrasqueira', icon: 'bi-fire' },
    'mobiliado' => { label: 'Mobiliado', icon: 'bi-house-heart' },
    'sacada' => { label: 'Sacada', icon: 'bi-door-open' },
    'decorado' => { label: 'Decorado', icon: 'bi-palette' },
    'closet' => { label: 'Closet', icon: 'bi-box' },
    'semi_mobiliado' => { label: 'Semi Mobiliado', icon: 'bi-house' },
    'lavabo' => { label: 'Lavabo', icon: 'bi-droplet' },
    'lavanderia' => { label: 'Lavanderia', icon: 'bi-basket' },
    'hidromassagem' => { label: 'Hidromassagem', icon: 'bi-moisture' },
    'piscina' => { label: 'Piscina', icon: 'bi-water' },
    'sala_estar' => { label: 'Sala de Estar', icon: 'bi-tv' },
    'sala_jantar' => { label: 'Sala de Jantar', icon: 'bi-egg-fried' },
    'varanda' => { label: 'Varanda', icon: 'bi-door-open' }
  }.freeze
  
  # Retorna contador de imóveis com determinada característica
  def characteristic_counter(characteristic)
    Rails.cache.fetch("characteristic_count:#{characteristic}", expires_in: 1.hour) do
      Habitation.active.with_photos.send(characteristic).count
    rescue NoMethodError
      0
    end
  end
  
  # Retorna badges de características do imóvel
  def property_badges(property)
    badges = []
    
    # Lançamento
    badges << { text: 'NOVIDADE', class: 'badge-new' } if property.lancamento_flag
    
    # Frente/Vista/Quadra mar
    badges << { text: 'Vista Mar', class: 'badge-ocean' } if property_has_characteristic?(property, 'vista_mar')
    badges << { text: 'Frente Mar', class: 'badge-ocean' } if property_has_characteristic?(property, 'frente_mar')
    badges << { text: 'Quadra Mar', class: 'badge-ocean' } if property_has_characteristic?(property, 'quadra_mar')
    
    # Churrasqueira
    badges << { text: 'Churrasqueira', class: 'badge-feature' } if property_has_characteristic?(property, 'churrasqueira')
    
    # Mobiliado
    badges << { text: 'Mobiliado', class: 'badge-furnished' } if property.mobiliado_flag
    
    # Decorado
    badges << { text: 'Decorado', class: 'badge-feature' } if property_has_characteristic?(property, 'decorado')
    
    badges.take(3) # Limitar a 3 badges
  end
  
  # Verifica se o imóvel tem determinada característica
  def property_has_characteristic?(property, characteristic)
    return false unless property
    
    case characteristic
    when 'frente_mar'
      property.caracteristicas&.dig('frente_mar') == 'true' ||
        check_jsonb_text(property.caracteristicas, 'frente', 'mar')
    when 'quadra_mar'
      property.caracteristicas&.dig('quadra_mar') == 'true' ||
        check_jsonb_text(property.caracteristicas, 'quadra', 'mar')
    when 'vista_mar'
      check_jsonb_text(property.caracteristicas, 'vista', 'mar')
    when 'churrasqueira'
      check_jsonb_text(property.caracteristicas, 'churrasqueira') ||
        check_jsonb_array(property.infra_estrutura, 'churrasqueira')
    when 'mobiliado'
      property.mobiliado_flag == true
    when 'decorado'
      check_jsonb_text(property.caracteristicas, 'decorado')
    when 'piscina'
      property.piscina_flag == true ||
        check_jsonb_text(property.caracteristicas, 'piscina') ||
        check_jsonb_array(property.infra_estrutura, 'piscina')
    else
      false
    end
  end
  
  # Opções de ordenação
  def sort_options
    [
      ['Mais Recentes', 'newest'],
      ['Mais Antigos', 'oldest'],
      ['Menor Preço', 'price_asc'],
      ['Maior Preço', 'price_desc'],
      ['Menor Área', 'area_asc'],
      ['Maior Área', 'area_desc']
    ]
  end
  
  # Retorna label de ordenação atual
  def current_sort_label(sort)
    sort_options.find { |opt| opt[1] == sort }&.first || 'Mais Recentes'
  end
  
  # Toggle característica em array de características
  def toggle_characteristic(current_chars, char)
    chars = current_chars.is_a?(Array) ? current_chars : (current_chars.present? ? [current_chars] : [])
    
    if chars.include?(char)
      chars - [char]
    else
      chars + [char]
    end
  end
  
  private
  
  def check_jsonb_text(jsonb, *keywords)
    return false unless jsonb.is_a?(Hash)
    
    text = jsonb.values.join(' ').downcase
    keywords.all? { |keyword| text.include?(keyword.downcase) }
  end
  
  def check_jsonb_array(jsonb, keyword)
    return false unless jsonb.is_a?(Array)
    
    jsonb.any? { |item| item.to_s.downcase.include?(keyword.downcase) }
  end
end

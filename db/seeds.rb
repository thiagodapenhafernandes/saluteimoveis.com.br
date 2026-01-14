# Limpar dados existentes
puts "Limpando dados existentes..."
Habitation.destroy_all

puts "Criando imóveis de exemplo..."

# Cidades e bairros
cidades_bairros = {
  'São Paulo' => ['Vila Mariana', 'Moema', 'Pinheiros', 'Jardins', 'Itaim Bibi'],
  'Rio de Janeiro' => ['Ipanema', 'Leblon', 'Copacabana', 'Botafogo', 'Barra da Tijuca'],
  'Belo Horizonte' => ['Savassi', 'Lourdes', 'Funcionários', 'Belvedere'],
  'Curitiba' => ['Batel', 'Bigorrilho', 'Centro', 'Água Verde']
}

# URLs de imagens de exemplo (placeholder)
sample_images = [
  'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
  'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800',
  'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=800'
]

categorias = ['Apartamento', 'Casa', 'Cobertura', 'Studio', 'Loft']
status_list = ['Venda', 'Locação']

# Criar 20 imóveis variados
20.times do |i|
  cidade = cidades_bairros.keys.sample
  bairro = cidades_bairros[cidade].sample
  categoria = categorias.sample
  status = status_list.sample
  
  is_venda = status == 'Venda'
  is_destaque = i < 8  # Primeiros 8 são destaque
  is_lancamento = i < 6  # Primeiros 6 são lançamento
  
  # Gerar preços realistas
  base_price = case categoria
  when 'Apartamento'
    rand(300_000..1_500_000)
  when 'Casa'
    rand(500_000..2_500_000)
  when 'Cobertura'
    rand(800_000..3_000_000)
  when 'Studio'
    rand(200_000..600_000)
  when 'Loft'
    rand(400_000..1_200_000)
  end
  
  # Se for locação, dividir por 300 (aproximadamente)
  preco_venda = is_venda ? base_price : nil
  preco_locacao = is_venda ? nil : (base_price / 300.0).round
  
  dormitorios = categoria == 'Studio' ? 1 : rand(1..4)
  suites = dormitorios > 1 ? rand(0..dormitorios-1) : 0
  
  habitation = Habitation.create!(
    codigo: "IMOV#{1000 + i}",
    categoria: categoria,
    status: status,
    situacao: 'Disponível',
    tipo: 'Unitário',
    
    # Endereço
    tipo_endereco: ['Rua', 'Avenida', 'Alameda'].sample,
    endereco: "#{['das Flores', 'dos Girassóis', 'Principal', 'Central', 'do Comércio'].sample}",
    numero: rand(100..9999).to_s,
    bairro: bairro,
    cidade: cidade,
    uf: case cidade
    when 'São Paulo' then 'SP'
    when 'Rio de Janeiro' then 'RJ'
    when 'Belo Horizonte' then 'MG'
    when 'Curitiba' then 'PR'
    end,
    cep: "#{rand(10000..99999)}-#{rand(100..999)}",
    
    # Geolocalização (coordenadas aproximadas)
    latitude: -23.0 + rand(-2.0..2.0),
    longitude: -46.0 + rand(-2.0..2.0),
    
    # Características
    dormitorios_qtd: dormitorios,
    suites_qtd: suites,
    banheiros_qtd: rand(1..3),
    vagas_qtd: rand(1..3),
    
    # Áreas
    area_total_m2: rand(45..250),
    area_privativa_m2: rand(40..200),
    
    # Preços (em centavos)
    valor_venda_cents: preco_venda ? preco_venda * 100 : nil,
    valor_locacao_cents: preco_locacao ? preco_locacao * 100 : nil,
    valor_condominio_cents: rand(200..800) * 100,
    valor_iptu_cents: rand(100..500) * 100,
    
    # JSONB - Características
    caracteristicas: {
      'Varanda' => [true, false].sample,
      'Sacada' => [true, false].sample,
      'Armários embutidos' => true,
      'Piso' => ['Porcelanato', 'Madeira', 'Cerâmica'].sample,
      'Iluminação' => 'Natural'
    },
    
    # JSONB - Infraestrutura
    infra_estrutura: {
      'Elevador' => categoria != 'Casa',
      'Portaria 24h' => true,
      'Salão de festas' => [true, false].sample,
      'Piscina' => [true, false].sample,
      'Academia' => [true, false].sample,
      'Playground' => [true, false].sample,
      'Churrasqueira' => [true, false].sample
    },
    
    # JSONB - Fotos
    pictures: sample_images.sample(rand(3..5)).map.with_index do |url, idx|
      { 'url' => url, 'descricao' => "Foto #{idx + 1}", 'principal' => idx == 0 }
    end,
    
    # Descrições
    titulo_anuncio: "#{categoria} #{dormitorios} dormitórios em #{bairro}",
    descricao_web: "Excelente #{categoria.downcase} localizado no bairro #{bairro}, #{cidade}. " \
                   "Com #{dormitorios} dormitórios#{suites > 0 ? ", sendo #{suites} suíte#{suites > 1 ? 's' : ''}" : ''}, " \
                   "#{rand(1..3)} banheiros e #{rand(1..3)} vagas de garagem. " \
                   "Próximo a comércio, escolas e transporte público. Acabamento de primeira linha. " \
                   "#{['Aceita financiamento bancário.', 'Documentação em ordem.', 'Pronto para morar.'].sample}",
    
    # Flags
    exibir_no_site_flag: true,
    destaque_web_flag: is_destaque,
    lancamento_flag: is_lancamento,
    aceita_financiamento_flag: is_venda,
    aceita_permuta_flag: is_venda && [true, false].sample,
    mobiliado_flag: [true, false].sample,
    
    # Datas
    data_atualizacao_crm: rand(1..30).days.ago,
    data_cadastro_crm: rand(30..90).days.ago
  )
  
  print "."
end

puts "\n\n✅ #{Habitation.count} imóveis criados com sucesso!"
puts "   - #{Habitation.for_sale.count} para venda"
puts "   - #{Habitation.for_rent.count} para locação"
puts "   - #{Habitation.featured.count} em destaque"
puts "   - #{Habitation.lancamento.count} lançamentos"
puts "\n🏠 Categorias:"
Habitation.group(:categoria).count.each do |categoria, count|
  puts "   - #{categoria}: #{count}"
end
puts "\n📍 Cidades:"
Habitation.group(:cidade).count.each do |cidade, count|
  puts "   - #{cidade}: #{count}"
end


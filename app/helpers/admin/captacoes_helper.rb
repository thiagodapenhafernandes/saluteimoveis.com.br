module Admin::CaptacoesHelper
  CAPTACAO_FEATURE_LABELS = {
    "agua quente" => "Água Quente",
    "aquecimento a gas" => "Aquecimento a gás",
    "aquecimento gas" => "Aquecimento a gás",
    "ar condicionado" => "Ar-condicionado",
    "area de servico" => "Área de serviço",
    "armarios nos quartos" => "Armários nos quartos",
    "armarios quartos" => "Armários nos quartos",
    "banheira hidromassagem" => "Banheira Hidromassagem",
    "banheiro auxiliar" => "Banheiro Auxiliar",
    "banheiro social" => "Banheiro Social",
    "bicicletario" => "Bicicletário",
    "churrasqueira a carvao" => "Churrasqueira à carvão",
    "churrasqueira a gas" => "Churrasqueira à gás",
    "churrasqueira coletiva" => "Churrasqueira Coletiva",
    "condominio fechado" => "Condomínio Fechado",
    "cozinha americana" => "Cozinha Americana",
    "cozinha gourmet com churrasqueira" => "Cozinha gourmet com churrasqueira",
    "cozinha planejada" => "Cozinha planejada",
    "dependencia empregada" => "Dependência Empregada",
    "dormitorio com armarios" => "Dormitório com Armários",
    "estar intimo" => "Estar Íntimo",
    "fechadura digital" => "Fechadura digital",
    "frente mar" => "Frente Mar",
    "gas central" => "Gás Central",
    "hall entrada" => "Hall Entrada",
    "home theater" => "Home Theater",
    "living hall" => "Living Hall",
    "mobiliado decorado" => "Mobiliado Decorado",
    "pet place" => "Pet place",
    "piscina coletiva" => "Piscina Coletiva",
    "piso elevado" => "Piso Elevado",
    "portaria 24h" => "Portaria 24h",
    "quadra mar" => "Quadra Mar",
    "quadra poliesportiva" => "Quadra poliesportiva",
    "sacada com churrasqueira" => "Sacada com Churrasqueira",
    "sacada fechada" => "Sacada Fechada",
    "sacada integrada" => "Sacada Integrada",
    "sala com armarios" => "Sala com Armários",
    "sala de estar" => "Sala de Estar",
    "sala de jantar" => "Sala de Jantar",
    "sala fitness" => "Sala Fitness",
    "salao de festas" => "Salão de festas",
    "sem mobilia" => "Sem Mobília",
    "semi mobiliado" => "Semi Mobiliado",
    "sol da manha" => "Sol da manhã",
    "sol da tarde" => "Sol da tarde",
    "sol o dia todo" => "Sol o dia todo",
    "vista mar" => "Vista Mar",
    "vista panoramica" => "Vista Panorâmica",
    "vista para o mar" => "Vista para o Mar"
  }.freeze

  def captacao_feature_options(*groups)
    options = groups.flatten.compact_blank.map { |value| captacao_feature_label(value) }.compact_blank
    options.index_by { |label| captacao_feature_key(label) }.values.sort_by { |label| captacao_feature_key(label) }
  end

  def captacao_feature_selected?(selected_values, label)
    selected_keys = Array(selected_values).map { |value| captacao_feature_key(captacao_feature_label(value) || value) }
    selected_keys.include?(captacao_feature_key(label))
  end

  private

  def captacao_feature_label(value)
    raw = value.to_s.strip
    return if raw.blank?

    normalized_key = captacao_feature_key(raw.tr("_", " "))
    return CAPTACAO_FEATURE_LABELS[normalized_key] if CAPTACAO_FEATURE_LABELS.key?(normalized_key)
    return if raw.match?(/\A[a-z0-9]+(?:_[a-z0-9]+)+\z/)

    raw.squish
  end

  def captacao_feature_key(value)
    I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, " ")
        .squish
  end
end

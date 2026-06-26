require "set"

module Habitation::CategoryTaxonomy
  extend ActiveSupport::Concern

  CATEGORY_ALIASES = {
    "Galpão para condomínio" => "Galpão em condomínio",
    "Salas/Conjuntos" => "Sala Comercial"
  }.freeze

  INTAKE_CATEGORY_GROUPS = {
    "comerciais_industriais" => [
      "Box", "Built to Suit", "Casa comercial", "Condomínio Industrial", "Coworking",
      "Depósito", "Galpão", "Galpão Industrial", "Galpão em condomínio", "Loja",
      "Loteamento Industrial", "Pavilhão", "Ponto Comercial", "Prédio Comercial",
      "Sala Comercial"
    ],
    "empreendimento" => ["Condomínio", "Empreendimento"],
    "imoveis_residenciais" => [
      "Apartamento", "Casa", "Casa em Condomínio", "Chácara", "Cobertura",
      "Kitnet", "Loft", "Sobrado", "Studio", "Sítio"
    ],
    "terrenos" => ["Terreno", "Terreno em Condomínio", "Terreno Comercial", "Terreno Industrial", "Área"]
  }.freeze

  INTAKE_CATEGORY_TYPE_BY_GROUP = {
    "comerciais_industriais" => "Unitário",
    "empreendimento" => "Empreendimento",
    "imoveis_residenciais" => "Unitário",
    "terrenos" => "Unitário"
  }.freeze

  INTAKE_CATEGORY_LABELS = {
    "comerciais_industriais" => "Comerciais e industriais",
    "empreendimento" => "Empreendimento",
    "imoveis_residenciais" => "Imóveis residenciais",
    "terrenos" => "Terrenos"
  }.freeze

  FEATURE_OPTIONS_BY_KIND = {
    "residencial" => [
      "Adega", "Água quente", "Alarme", "Aquecimento elétrico", "Aquecimento a gás",
      "Ar central", "Ar-condicionado", "Área de serviço", "Armário embutido",
      "Armários nos quartos", "Banheiro auxiliar", "Banheiro social", "Bar", "Calefação",
      "Churrasqueira", "Churrasqueira a carvão", "Churrasqueira a gás", "Copa",
      "Copa/cozinha", "Cozinha", "Cozinha americana", "Cozinha com tanque",
      "Cozinha montada", "Cozinha planejada", "Deck",
      "Dependência de empregada", "Despensa", "Dormitório com armário", "Edícula",
      "Escritório", "Estar íntimo", "Fechadura digital", "Frente mar", "Hidromassagem",
      "Home theater", "Jardim de inverno", "Lareira", "Lavabo", "Living", "Living hall",
      "Mobiliado", "Mobiliado decorado", "Pátio", "Piscina", "Porão", "Quintal",
      "Reformado", "Sacada", "Sacada aberta", "Sacada com churrasqueira",
      "Sacada fechada", "Sacada integrada", "Sala", "Sala com armários",
      "Sala de estar", "Sala de jantar", "Sala de TV", "Sauna", "Semi mobiliado",
      "Sol da manhã", "Sol da tarde", "Sol o dia todo", "Split", "Suíte master", "Quadra mar",
      "Sótão", "Terraço", "TV a cabo", "Vista mar", "Vista panorâmica", "WC empregada"
    ],
    "comercial" => [
      "Alarme", "Ar central", "Ar-condicionado", "Banheiro social", "Canaletas no rodapé",
      "Copa", "Copa/cozinha", "Cozinha", "Cozinha americana", "Escritório",
      "Espera split", "Forro", "Lavabo", "Living", "Monitoramento", "Piso elevado",
      "Sala", "Sala com armários", "Sala de estar", "Split", "Vigia externo",
      "Vigia interno", "Vista panorâmica", "Vitrine"
    ],
    "galpao" => [
      "Alarme", "Área de serviço", "Canaletas no rodapé", "Copa", "Cozinha",
      "Cozinha industrial", "Escritório", "Espera split", "Forro", "Gradeado",
      "Mezanino", "Monitoramento", "Pátio", "Pé-direito alto", "Piso elevado",
      "Sistema de segurança", "Vestiário", "Vigia externo", "Vigia interno", "Vitrine"
    ],
    "terreno" => [
      "Aterrado", "Cercado", "Com edificação", "Construção alvenaria", "Esquina",
      "Frente mar", "Frente para mar", "Gradeado", "Murado", "Pátio"
    ],
    "empreendimento" => [
      "Condomínio fechado", "Decorado", "Diferenciado", "Duplex", "Frente mar",
      "Garden", "Lançamento", "Mobiliado decorado", "Quadra mar", "Reformado",
      "Triplex", "Vista mar", "Vista panorâmica"
    ]
  }.freeze

  INFRASTRUCTURE_OPTIONS_BY_KIND = {
    "residencial" => [
      "Água", "Aquecimento central", "Bicicletário", "Brinquedoteca",
      "Churrasqueira condomínio", "Circuito fechado TV", "Condomínio fechado",
      "Depósito", "Elevador", "Elevador de serviço", "Espaço gourmet",
      "Estacionamento", "Estacionamento visitantes", "Gás central", "Gerador de energia",
      "Guarita", "Interfone", "Jardim", "Lavanderia", "Piscina aquecida",
      "Piscina coletiva", "Piscina infantil", "Pista caminhada", "Playground",
      "Portaria", "Portaria 24h", "Porteiro eletrônico", "Quadra de esportes",
      "Quadra de padel", "Quadra poliesportiva", "Quadra de tênis", "Quiosque",
      "Sala fitness", "Salão de festas", "Salão de jogos", "Sauna condomínio",
      "Segurança patrimonial", "Spa", "Terraço coletivo", "Vigilância 24h", "Zelador"
    ],
    "comercial" => [
      "Água", "Aquecimento central", "Cabine de força", "Circuito fechado TV",
      "Depósito", "Elevador", "Elevador de serviço", "Empresa de monitoramento",
      "Energia elétrica", "Energia trifásica", "Entrada de serviço independente",
      "Estacionamento", "Estacionamento visitantes", "Garagem", "Gerador de energia",
      "Guarita", "Heliponto", "Interfone", "Marquise", "Portaria", "Portaria 24h",
      "Portaria blindada", "Porteiro eletrônico", "Sala de recepção",
      "Segurança patrimonial", "Vigilância 24h", "Zelador"
    ],
    "galpao" => [
      "Água", "Cabine de força", "Capacidade piso", "Circuito fechado TV",
      "Depósito", "Empresa de monitoramento", "Energia elétrica", "Energia trifásica",
      "Entrada de serviço independente", "Estacionamento", "Garagem", "Garagem coberta",
      "Gradil", "Guarita", "Interfone", "Pavimentação", "Portaria", "Portaria 24h",
      "Rede de esgoto", "Segurança patrimonial", "Tubulação", "Vigilância 24h"
    ],
    "terreno" => [
      "Água", "Construção mista", "Energia elétrica", "Energia trifásica",
      "Gradil", "Ônibus próximo", "Pavimentação", "Poço artesiano",
      "Possui viabilidade", "Rede de esgoto"
    ],
    "empreendimento" => [
      "Água", "Aquecimento central", "Bicicletário", "Brinquedoteca",
      "Churrasqueira condomínio", "Cinema", "Circuito fechado TV", "Condomínio fechado",
      "Elevador", "Elevador de serviço", "Espaço gourmet", "Estacionamento visitantes",
      "Gás central", "Gerador de energia", "Guarita", "Heliponto", "Interfone",
      "Jardim", "Lavanderia", "Piscina aquecida", "Piscina coletiva", "Piscina infantil",
      "Pista caminhada", "Playground", "Portaria", "Portaria 24h", "Porteiro eletrônico",
      "Quadra de esportes", "Quadra de padel", "Quadra poliesportiva", "Quadra de tênis",
      "Quiosque", "Sala fitness", "Salão de festas", "Salão de jogos",
      "Sauna condomínio", "Segurança patrimonial", "Spa", "Terraço coletivo",
      "Vigilância 24h", "Zelador"
    ]
  }.freeze

  class_methods do
    def category_group_for(category)
      normalized = normalize_category(category)
      return "empreendimento" if normalized.casecmp("Empreendimento").zero?

      INTAKE_CATEGORY_GROUPS.find { |_group, categories| categories.include?(normalized) }&.first
    end

    def normalize_category(category)
      normalized = category.to_s.strip
      CATEGORY_ALIASES.fetch(normalized, normalized)
    end

    def default_category_for_group(group)
      INTAKE_CATEGORY_GROUPS[group.to_s]&.first
    end

    def feature_options_for_kind(kind, catalog_options = [], selected_options: [])
      options_for_kind(FEATURE_OPTIONS_BY_KIND, kind, catalog_options, selected_options: selected_options)
    end

    def infrastructure_options_for_kind(kind, catalog_options = [], selected_options: [])
      options_for_kind(INFRASTRUCTURE_OPTIONS_BY_KIND, kind, catalog_options, selected_options: selected_options, category: "infrastructure")
    end

    private

    def options_for_kind(source, kind, catalog_options, selected_options:, category: "feature")
      kind_key = source.key?(kind.to_s) ? kind.to_s : "residencial"
      allowed = source.fetch(kind_key)
      allowed_keys = normalized_option_keys(allowed, category: category)
      catalog = Array(catalog_options).select do |option|
        allowed_keys.include?(normalized_option_key(option, category: category))
      end

      normalize_options(allowed + catalog + Array(selected_options), category: category)
    end

    def normalize_options(options, category: "feature")
      AttributeOptions::HabitationFeatureNormalizer
        .normalize_list(options, category: category)
        .sort_by { |option| normalized_option_key(option, category: category) }
    end

    def normalized_option_keys(options, category: "feature")
      Array(options).map { |option| normalized_option_key(option, category: category) }.to_set
    end

    def normalized_option_key(option, category: "feature")
      label = AttributeOptions::HabitationFeatureNormalizer.label(option, category: category)
      AttributeOptions::HabitationFeatureNormalizer.key(label)
    end
  end

  def cadastro_type
    self.class.category_group_for(categoria) || "imoveis_residenciais"
  end

  def property_kind
    return "empreendimento" if tipo.to_s.casecmp("Empreendimento").zero? || categoria.to_s.match?(/\A(?:empreendimento|condom[ií]nio)\z/i)
    return "casa_rua" if street_house?
    return "terreno" if categoria.to_s.match?(/terreno|área|area/i)
    return "galpao" if categoria.to_s.match?(/galp|industrial|dep[oó]sito|pavilh|loteamento/i)
    return "sala_comercial" if categoria.to_s.match?(/box|built|sala|loja|comercial|coworking|ponto|conjunto/i)

    "residencial"
  end

  def property_kind=(value)
    group = case value.to_s
            when "sala_comercial", "galpao" then "comerciais_industriais"
            when "terreno" then "terrenos"
            when "empreendimento" then "empreendimento"
            else "imoveis_residenciais"
            end

    self.categoria = self.class.default_category_for_group(group)
    self.tipo = INTAKE_CATEGORY_TYPE_BY_GROUP.fetch(group, "Unitário")
  end

  def property_kind_commercial?
    property_kind.in?(%w[sala_comercial galpao])
  end

  def property_kind_empreendimento?
    property_kind == "empreendimento"
  end

  def feature_catalog_options(catalog_options = [])
    self.class.feature_options_for_kind(feature_catalog_kind, catalog_options, selected_options: caracteristicas_imovel)
  end

  def infrastructure_catalog_options(catalog_options = [])
    self.class.infrastructure_options_for_kind(feature_catalog_kind, catalog_options, selected_options: caracteristicas_predio)
  end

  def default_intake_feature_options
    self.class.feature_options_for_kind(feature_catalog_kind)
  end

  def default_intake_infrastructure_options
    self.class.infrastructure_options_for_kind(feature_catalog_kind)
  end

  def feature_catalog_kind
    case property_kind
    when "sala_comercial" then "comercial"
    when "casa_rua" then "residencial"
    else property_kind
    end
  end
end

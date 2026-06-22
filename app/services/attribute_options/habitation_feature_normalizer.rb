# frozen_string_literal: true

module AttributeOptions
  module HabitationFeatureNormalizer
    FEATURE_LABELS = {
      "adega" => "Adega",
      "agua quente" => "Água quente",
      "alarme" => "Alarme",
      "antena parabolica" => "Antena parabólica",
      "aquecimento eletrico" => "Aquecimento elétrico",
      "aquecimento a gas" => "Aquecimento a gás",
      "aquecimento gas" => "Aquecimento a gás",
      "ar central" => "Ar central",
      "ar condicionado" => "Ar-condicionado",
      "area de servico" => "Área de serviço",
      "area servico" => "Área de serviço",
      "armario embutido" => "Armário embutido",
      "armarios embutidos" => "Armário embutido",
      "armarios nos quartos" => "Armários nos quartos",
      "armarios quartos" => "Armários nos quartos",
      "banheira hidromassagem" => "Banheira hidromassagem",
      "banheiro auxiliar" => "Banheiro auxiliar",
      "banho auxiliar" => "Banheiro auxiliar",
      "banheiro social" => "Banheiro social",
      "banho social" => "Banheiro social",
      "bar" => "Bar",
      "bicicletario" => "Bicicletário",
      "canaletas no rodape" => "Canaletas no rodapé",
      "cerca eletrica" => "Cerca elétrica",
      "churrasqueira" => "Churrasqueira",
      "churrasqueira a carvao" => "Churrasqueira a carvão",
      "churrasqueira a gas" => "Churrasqueira a gás",
      "churrasqueira coletiva" => "Churrasqueira coletiva",
      "condominio fechado" => "Condomínio fechado",
      "construcao alvenaria" => "Construção alvenaria",
      "copa" => "Copa",
      "copa cozinha" => "Copa/cozinha",
      "cozinha" => "Cozinha",
      "cozinha americana" => "Cozinha americana",
      "cozinha com tanque" => "Cozinha com tanque",
      "cozinha gourmet com churrasqueira" => "Cozinha gourmet com churrasqueira",
      "cozinha industrial" => "Cozinha industrial",
      "cozinha montada" => "Cozinha montada",
      "cozinha planejada" => "Cozinha planejada",
      "deck" => "Deck",
      "dependencia de empregada" => "Dependência de empregada",
      "dependencia empregada" => "Dependência de empregada",
      "dependenciade empregada" => "Dependência de empregada",
      "despensa" => "Despensa",
      "diferenciado" => "Diferenciado",
      "dormitorio com armario" => "Dormitório com armário",
      "dormitorio com armarios" => "Dormitório com armários",
      "duplex" => "Duplex",
      "edicula" => "Edícula",
      "escritorio" => "Escritório",
      "espera split" => "Espera split",
      "estar intimo" => "Estar íntimo",
      "fechadura digital" => "Fechadura digital",
      "forro" => "Forro",
      "frente mar" => "Frente mar",
      "garden" => "Garden",
      "gas central" => "Gás central",
      "gradeado" => "Gradeado",
      "hall entrada" => "Hall de entrada",
      "hidromassagem" => "Hidromassagem",
      "home theater" => "Home theater",
      "jardim inverno" => "Jardim de inverno",
      "lareira" => "Lareira",
      "lavabo" => "Lavabo",
      "living" => "Living",
      "living hall" => "Living hall",
      "living lavabo" => "Lavabo",
      "mezanino" => "Mezanino",
      "mobiliado" => "Mobiliado",
      "mobiliado decorado" => "Mobiliado decorado",
      "monitoramento" => "Monitoramento",
      "patio" => "Pátio",
      "pet place" => "Pet place",
      "piscina" => "Piscina",
      "piscina coletiva" => "Piscina coletiva",
      "piso elevado" => "Piso elevado",
      "porao" => "Porão",
      "quadra mar" => "Quadra mar",
      "quadra poliesportiva" => "Quadra poliesportiva",
      "quintal" => "Quintal",
      "reformado" => "Reformado",
      "sacada" => "Sacada",
      "sacada aberta" => "Sacada aberta",
      "sacada com churrasqueira" => "Sacada com churrasqueira",
      "sacada fechada" => "Sacada fechada",
      "sacada integrada" => "Sacada integrada",
      "sala armarios" => "Sala com armários",
      "sala com armarios" => "Sala com armários",
      "sala estar" => "Sala de estar",
      "sala de estar" => "Sala de estar",
      "sala jantar" => "Sala de jantar",
      "sala de jantar" => "Sala de jantar",
      "sala fitness" => "Sala fitness",
      "sala t v" => "Sala de TV",
      "sala tv" => "Sala de TV",
      "salao de festas" => "Salão de festas",
      "sauna" => "Sauna",
      "sem mobilia" => "Sem mobília",
      "semi mobiliado" => "Semi mobiliado",
      "sol da manha" => "Sol da manhã",
      "sol da tarde" => "Sol da tarde",
      "sol o dia todo" => "Sol o dia todo",
      "split" => "Split",
      "suite master" => "Suíte master",
      "sotao" => "Sótão",
      "terraco" => "Terraço",
      "triplex" => "Triplex",
      "tv cabo" => "TV a cabo",
      "tvcabo" => "TV a cabo",
      "vigia externo" => "Vigia externo",
      "vigia interno" => "Vigia interno",
      "vista mar" => "Vista mar",
      "vista panoramica" => "Vista panorâmica",
      "vista para o mar" => "Vista para o mar",
      "vitrine" => "Vitrine",
      "wc empregada" => "WC empregada",
      "w c empregada" => "WC empregada"
    }.freeze

    INFRASTRUCTURE_LABELS = FEATURE_LABELS.merge(
      "agua" => "Água",
      "aquecimento central" => "Aquecimento central",
      "box de praia" => "Box de praia",
      "brinquedoteca" => "Brinquedoteca",
      "cabine de forca" => "Cabine de força",
      "capacidade piso" => "Capacidade piso",
      "churrasqueira condominio" => "Churrasqueira condomínio",
      "circuito fechado t v" => "Circuito fechado TV",
      "circuito fechado tv" => "Circuito fechado TV",
      "circuito interno tv" => "Circuito interno TV",
      "deposito" => "Depósito",
      "elevador" => "Elevador",
      "elevador com" => "Elevador",
      "elevador servico" => "Elevador de serviço",
      "empresa de monitoramento" => "Empresa de monitoramento",
      "energia eletrica" => "Energia elétrica",
      "energia trifasica" => "Energia trifásica",
      "entrada servico independente" => "Entrada de serviço independente",
      "espaco gourmet" => "Espaço gourmet",
      "estacionamento" => "Estacionamento",
      "estacionamento visitantes" => "Estacionamento visitantes",
      "garagem coberta" => "Garagem coberta",
      "gerador energia" => "Gerador de energia",
      "gradil" => "Gradil",
      "guarita" => "Guarita",
      "heliponto" => "Heliponto",
      "interfone" => "Interfone",
      "jardim" => "Jardim",
      "lavanderia" => "Lavanderia",
      "onibus proximo" => "Ônibus próximo",
      "pavimentacao" => "Pavimentação",
      "pilotis" => "Pilotis",
      "piscina aquecida" => "Piscina aquecida",
      "piscina infantil" => "Piscina infantil",
      "pista caminhada" => "Pista caminhada",
      "playground" => "Playground",
      "poco artesiano" => "Poço artesiano",
      "portaria" => "Portaria",
      "portaria 24 h" => "Portaria 24h",
      "portaria 24h" => "Portaria 24h",
      "portaria 24 hrs" => "Portaria 24h",
      "portaria 24hs" => "Portaria 24h",
      "portaria24 hrs" => "Portaria 24h",
      "portaria blindada" => "Portaria blindada",
      "portoes com eclusa" => "Portões com eclusa",
      "porteiro eletronico" => "Porteiro eletrônico",
      "possui viabilidade" => "Possui viabilidade",
      "quadra esportes" => "Quadra de esportes",
      "quadra tenis" => "Quadra de tênis",
      "quadra de padel" => "Quadra de padel",
      "quadra padel" => "Quadra de padel",
      "padel" => "Quadra de padel",
      "quiosque" => "Quiosque",
      "rede esgoto" => "Rede de esgoto",
      "sala de recepcao" => "Sala de recepção",
      "sala ginastica" => "Sala fitness",
      "sala jogos" => "Sala de jogos",
      "salao festas" => "Salão de festas",
      "salao jogos" => "Salão de jogos",
      "sauna condominio" => "Sauna condomínio",
      "seguranca patrimonial" => "Segurança patrimonial",
      "spa" => "Spa",
      "terraco coletivo" => "Terraço coletivo",
      "terraco col" => "Terraço coletivo",
      "tubulacao" => "Tubulação",
      "vigilancia24 horas" => "Vigilância 24h",
      "zelador" => "Zelador"
    ).freeze

    module_function

    def label(value, category: "feature")
      raw = humanized_raw(value)
      return if raw.blank?

      labels = category.to_s == "infrastructure" ? INFRASTRUCTURE_LABELS : FEATURE_LABELS
      labels[key(raw)] || raw.downcase.squish.capitalize
    end

    def key(value)
      I18n.transliterate(humanized_raw(value))
          .downcase
          .gsub(/[^a-z0-9]+/, " ")
          .squish
    end

    def humanized_raw(value)
      value.to_s
           .strip
           .tr("_", " ")
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1 \\2')
           .gsub(/([a-z\d])([A-Z])/, '\\1 \\2')
           .gsub(/([A-Za-z])(\d)/, '\\1 \\2')
           .gsub(/(\d)([A-Za-z])/, '\\1 \\2')
           .squish
    end

    def normalize_list(values, category: "feature")
      Array(values)
        .flatten
        .filter_map { |value| label(value, category: category) }
        .index_by { |value| key(value) }
        .values
    end

    def normalize_hash(hash)
      normalized = {}

      hash.each do |raw_key, raw_value|
        canonical = label(raw_value.presence || raw_key, category: "feature")
        next if canonical.blank?

        normalized[canonical] = canonical
      end

      normalized
    end
  end
end

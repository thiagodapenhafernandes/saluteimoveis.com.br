require "rails_helper"

RSpec.describe Habitation::SearchScopes, type: :model do
  describe ".public_property_types" do
    it "includes fixed public type options even without published records" do
      expect(Habitation.public_property_types).to include("Diferenciado", "Garden")
    end
  end

  describe ".with_photos" do
    it "does not treat development photos as public photos for regular units" do
      unit_without_public_photo = create(
        :habitation,
        tipo: "Unitário",
        pictures: [],
        fotos_empreendimento: [{ "url" => "https://example.com/development.jpg" }]
      )

      result = Habitation.with_photos

      expect(result).not_to include(unit_without_public_photo)
    end

    it "treats linked development photos as public photos for linked units" do
      development = create(
        :habitation,
        codigo: "DEV-PHOTOS",
        tipo: "Empreendimento",
        pictures: [],
        fotos_empreendimento: [{ "url" => "https://example.com/development.jpg" }],
        skip_auto_audit: true
      )
      linked_unit = create(
        :habitation,
        tipo: "Unitário",
        pictures: [],
        codigo_empreendimento: development.codigo,
        use_development_photos_flag: false,
        skip_auto_audit: true
      )

      expect(Habitation.with_photos).to include(linked_unit)
    end

    it "allows development photos for developments" do
      development = create(
        :habitation,
        tipo: "Empreendimento",
        pictures: [],
        fotos_empreendimento: [{ "url" => "https://example.com/development.jpg" }]
      )

      expect(Habitation.with_photos).to include(development)
    end
  end

  describe ".admin_search_text" do
    it "matches developments and linked units by development name without accents or exact casing" do
      development = create(
        :habitation,
        tipo: "Empreendimento",
        codigo: "DEV-LABELLE",
        nome_empreendimento: "La Belle Tour Résidence",
        titulo_anuncio: "Lançamento no Centro"
      )
      unit = create(
        :habitation,
        codigo: "UNIT-LABELLE",
        codigo_empreendimento: development.codigo,
        nome_empreendimento: nil,
        titulo_anuncio: "Apartamento 2 suítes"
      )
      other = create(:habitation, codigo: "OTHER-RESIDENCE", nome_empreendimento: "Outro Residencial")

      result = Habitation.admin_search_text("belle la")

      expect(result).to include(development, unit)
      expect(result).not_to include(other)
    end

    it "matches address fields by street, number, zip code and neighborhood" do
      matching = create(:habitation, codigo: "ADDR-MATCH", endereco: nil, numero: nil, cep: nil, bairro: nil)
      Address.create!(
        addressable: matching,
        tipo_endereco: "Rua",
        logradouro: "2000",
        numero: "120",
        bairro: "Centro",
        cidade: "Balneário Camboriú",
        uf: "SC",
        cep: "88330-590"
      )
      other = create(:habitation, codigo: "ADDR-OTHER", endereco: "Rua 1000", numero: "80", cep: "88330-000", bairro: "Barra Sul")

      result = Habitation.admin_search_text("rua 2000 120 88330-590 centro")

      expect(result).to include(matching)
      expect(result).not_to include(other)
    end

    it "não casa palavras que aparecem só na descrição livre (evita ruído)" do
      on_street = create(:habitation, codigo: "RUA-CENTRAL", descricao_web: nil)
      Address.create!(addressable: on_street, tipo_endereco: "Avenida", logradouro: "Central",
                      bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")
      only_description = create(:habitation, codigo: "SO-DESC-7001", nome_empreendimento: nil,
                                titulo_anuncio: "Apartamento amplo",
                                descricao_web: "Imóvel com ar-condicionado central e posição central.")

      result = Habitation.admin_search_text("Central")

      expect(result).to include(on_street)
      expect(result).not_to include(only_description)
    end
  end

  describe ".dependencia_empregada" do
    it "matches Vista characteristics for dependencia de empregada" do
      matching = create(:habitation, caracteristicas: ["Dependência de Empregada"])
      create(:habitation, caracteristicas: ["Lavabo"])

      expect(Habitation.dependencia_empregada).to contain_exactly(matching)
    end
  end

  describe ".advanced_search" do
    it "filters by dependencia de empregada characteristic" do
      matching = create(:habitation, caracteristicas: ["Dep. Empregada"])
      non_matching = create(:habitation, caracteristicas: ["Lavanderia"])

      result = Habitation.advanced_search(characteristics: ["dependencia_empregada"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters by gourmet kitchen with barbecue" do
      matching = create(:habitation, caracteristicas: ["Cozinha Gourmet"], infra_estrutura: ["Churrasqueira"])
      non_matching = create(:habitation, caracteristicas: ["Cozinha Planejada"], infra_estrutura: ["Piscina"])

      result = Habitation.advanced_search(characteristics: ["cozinha_gourmet_churrasqueira"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters by morning sun using face" do
      matching = create(:habitation, face: "Leste")
      non_matching = create(:habitation, face: "Oeste")

      result = Habitation.advanced_search(characteristics: ["sol_manha"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters by afternoon sun using face" do
      matching = create(:habitation, face: "Oeste")
      non_matching = create(:habitation, face: "Leste")

      result = Habitation.advanced_search(characteristics: ["sol_tarde"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters by all day sun using face" do
      matching = create(:habitation, face: "Norte")
      non_matching = create(:habitation, face: "Sul")

      result = Habitation.advanced_search(characteristics: ["sol_dia_todo"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "keeps filtering regular public types by category" do
      matching = create(:habitation, categoria: "Apartamento")
      non_matching = create(:habitation, categoria: "Casa")

      result = Habitation.advanced_search(category: ["Apartamento"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters Garden selected as a public type by the garden flag" do
      matching = create(:habitation, garden_flag: true, categoria: "Apartamento")
      non_matching = create(:habitation, garden_flag: false, categoria: "Apartamento")

      result = Habitation.advanced_search(category: ["Garden"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end

    it "filters Diferenciado selected as a public type by its unique feature" do
      matching = create(:habitation, caracteristica_unica: ["Diferenciado"], categoria: "Apartamento")
      non_matching = create(:habitation, caracteristica_unica: ["Decorado"], categoria: "Apartamento")

      result = Habitation.advanced_search(category: ["Diferenciado"])

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end
  end
end

require "rails_helper"

RSpec.describe Habitation::SearchScopes, type: :model do
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
  end
end

require "rails_helper"

RSpec.describe "Habitation category taxonomy" do
  it "keeps Vista category groups available for intake forms" do
    groups = Habitation::CategoryTaxonomy::INTAKE_CATEGORY_GROUPS

    expect(groups["comerciais_industriais"]).to include("Box", "Galpão", "Sala Comercial")
    expect(groups["comerciais_industriais"]).not_to include("Salas/Conjuntos")
    expect(groups["empreendimento"]).to include("Condomínio", "Empreendimento")
    expect(groups["imoveis_residenciais"]).to include("Apartamento", "Kitnet", "Studio")
    expect(groups["terrenos"]).to include("Terreno", "Terreno Comercial", "Área")
  end

  it "classifies Vista commercial and land categories without falling back to residential" do
    expect(build(:habitation, categoria: "Condomínio Industrial").property_kind).to eq("galpao")
    expect(build(:habitation, categoria: "Depósito").property_kind).to eq("galpao")
    expect(build(:habitation, categoria: "Coworking").property_kind).to eq("sala_comercial")
    expect(build(:habitation, categoria: "Salas/Conjuntos").property_kind).to eq("sala_comercial")
    expect(build(:habitation, categoria: "Área").property_kind).to eq("terreno")
    expect(build(:habitation, categoria: "Condomínio", tipo: "Empreendimento").property_kind).to eq("empreendimento")
  end

  it "normalizes legacy Salas/Conjuntos category to Sala Comercial" do
    habitation = build(:habitation, categoria: "Salas/Conjuntos")

    habitation.valid?

    expect(habitation.categoria).to eq("Sala Comercial")
    expect(Habitation.category_group_for("Salas/Conjuntos")).to eq("comerciais_industriais")
  end

  it "filters feature options by property kind while preserving selected values" do
    terrain_options = Habitation.feature_options_for_kind(
      "terreno",
      ["Sacada", "Piso elevado", "Murado"],
      selected_options: ["Sacada"]
    )

    expect(terrain_options).to include("Murado", "Sacada")
    expect(terrain_options).not_to include("Piso elevado")
  end

  it "keeps charcoal and gas barbecue options available for residential features" do
    residential_options = Habitation.feature_options_for_kind("residencial", ["Churrasqueira à carvão"])

    expect(residential_options).to include("Churrasqueira a carvão", "Churrasqueira a gás")
  end
end

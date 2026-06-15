require "rails_helper"

RSpec.describe Seo::PropertySettingsBackfill do
  it "updates automatic property SEO from current habitation data" do
    habitation = create(
      :habitation,
      codigo: "8565",
      categoria: "Casa",
      slug: "casa-balneario-camboriu-centro-8565",
      titulo_anuncio: "Casa locação anual com 3 dormitórios no Centro"
    )
    seo = create(
      :seo_setting,
      page_name: "imovel:8565",
      canonical_key: "property:8565",
      page_type: "property_show",
      canonical_path: "/imoveis/apartamento-8565",
      meta_title: "Apartamento 8565 em Balneário Camboriú",
      og_title: "Apartamento 8565 em Balneário Camboriú",
      manual_mode: false
    )

    result = described_class.new(scope: SeoSetting.where(id: seo.id)).call

    expect(result.updated).to eq(1)
    expect(seo.reload).to have_attributes(
      canonical_path: "/imoveis/casa-balneario-camboriu-centro-8565",
      meta_title: "Casa locação anual com 3 dormitórios no Centro | Salute Imóveis",
      og_title: "Casa locação anual com 3 dormitórios no Centro | Salute Imóveis"
    )
    expect(seo.meta_title).to include(habitation.display_title)
  end

  it "preserves manual property SEO" do
    create(
      :habitation,
      codigo: "8566",
      categoria: "Casa",
      slug: "casa-balneario-camboriu-centro-8566",
      titulo_anuncio: "Casa locação anual no Centro"
    )
    seo = create(
      :seo_setting,
      page_name: "imovel:8566",
      canonical_key: "property:8566",
      page_type: "property_show",
      canonical_path: "/imoveis/apartamento-8566",
      meta_title: "Título manual preservado",
      og_title: "OG manual preservado",
      manual_mode: true
    )

    result = described_class.new(scope: SeoSetting.where(id: seo.id)).call

    expect(result.updated).to eq(0)
    expect(result.skipped_manual).to eq(1)
    expect(seo.reload).to have_attributes(
      canonical_path: "/imoveis/apartamento-8566",
      meta_title: "Título manual preservado",
      og_title: "OG manual preservado"
    )
  end

  it "reports changes without saving in dry run mode" do
    create(
      :habitation,
      codigo: "8567",
      categoria: "Casa",
      slug: "casa-balneario-camboriu-centro-8567",
      titulo_anuncio: "Casa anual no Centro"
    )
    seo = create(
      :seo_setting,
      page_name: "imovel:8567",
      canonical_key: "property:8567",
      page_type: "property_show",
      canonical_path: "/imoveis/apartamento-8567",
      meta_title: "Apartamento 8567",
      manual_mode: false
    )

    result = described_class.new(scope: SeoSetting.where(id: seo.id), dry_run: true).call

    expect(result.updated).to eq(1)
    expect(seo.reload).to have_attributes(
      canonical_path: "/imoveis/apartamento-8567",
      meta_title: "Apartamento 8567"
    )
  end
end

require "rails_helper"

RSpec.describe Portal::EligibilityScope do
  describe "#preview" do
    it "counts only VRSync listings exportable by the serializer" do
      Habitation.destroy_all

      integration = PortalIntegration.new(
        portal: "vivareal_vrsync",
        require_exibir_no_site: true,
        allowed_statuses: ["Venda"],
        allowed_business_types: ["venda"]
      )

      valid = create(
        :habitation,
        publicar_viva_real_vrsync: true,
        titulo_anuncio: "Apartamento válido",
        valor_venda_cents: 900_000_00,
        pictures: [{ "url" => "https://cdn.salute.test/foto-valida.jpg" }]
      )
      valid.create_address!(
        logradouro: "Rua 1000",
        numero: "10",
        bairro: "Centro",
        cidade: "Balneário Camboriú",
        uf: "SC",
        cep: "88330-000"
      )

      without_postal_code = create(
        :habitation,
        publicar_viva_real_vrsync: true,
        titulo_anuncio: "Apartamento sem CEP",
        valor_venda_cents: 850_000_00,
        pictures: [{ "url" => "https://cdn.salute.test/foto-valida.jpg" }]
      )
      without_postal_code.create_address!(
        logradouro: "Rua 1100",
        numero: "11",
        bairro: "Centro",
        cidade: "Balneário Camboriú",
        uf: "SC",
        cep: ""
      )

      without_jpg = create(
        :habitation,
        publicar_viva_real_vrsync: true,
        titulo_anuncio: "Apartamento sem foto JPG",
        valor_venda_cents: 800_000_00,
        pictures: [{ "url" => "https://cdn.salute.test/foto-invalida.png" }]
      )
      without_jpg.create_address!(
        logradouro: "Rua 1200",
        numero: "12",
        bairro: "Centro",
        cidade: "Balneário Camboriú",
        uf: "SC",
        cep: "88330-001"
      )

      preview = described_class.new(integration).preview

      expect(preview[:eligible_count]).to eq(1)
      expect(preview[:top_reasons]["dados_invalidos_vrsync"]).to eq(2)
    end
  end
end

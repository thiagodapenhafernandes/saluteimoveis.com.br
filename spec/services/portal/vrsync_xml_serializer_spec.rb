require "rails_helper"

RSpec.describe Portal::VrsyncXmlSerializer do
  it "serializes Viva Real listings with valid VRSync structure and media URLs" do
    original_app_host = ENV["APP_HOST"]
    ENV["APP_HOST"] = "https://saluteimoveis.com.br"
    integration = PortalIntegration.new(portal: "vivareal_vrsync")
    habitation = create(
      :habitation,
      categoria: "Apartamento",
      status: "Venda",
      titulo_anuncio: "Apartamento no Centro",
      descricao_web: "Descrição pública do imóvel.",
      valor_venda_cents: 1_250_000_00,
      valor_locacao_cents: 6_500_00,
      tipo_publicacao_viva_real: "super_destaque",
      divulgar_endereco_viva_real: "exata",
      pictures: [
        { "url" => "/rails/active_storage/blobs/proxy/foto-1.jpg" },
        { "url" => "https://cdn.salute.test/foto-2.jpeg" },
        { "url" => "https://cdn.salute.test/foto-3.png" }
      ]
    )
    habitation.create_address!(
      logradouro: "Avenida Brasil",
      numero: "3618",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: "88330-239"
    )
    unsupported_photo = create(
      :habitation,
      categoria: "Apartamento",
      status: "Venda",
      titulo_anuncio: "Apartamento com foto incompatível",
      descricao_web: "Não deve aparecer no XML VRSync.",
      valor_venda_cents: 900_000_00,
      pictures: [{ "url" => "https://cdn.salute.test/foto-invalida.png" }]
    )
    missing_postal_code = create(
      :habitation,
      categoria: "Apartamento",
      status: "Venda",
      titulo_anuncio: "Apartamento sem CEP",
      descricao_web: "Não deve aparecer no XML VRSync.",
      valor_venda_cents: 850_000_00,
      pictures: [{ "url" => "https://cdn.salute.test/foto-valida.jpg" }]
    )
    missing_postal_code.create_address!(
      logradouro: "Rua 1000",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: ""
    )

    xml = described_class.new(habitations: [habitation, unsupported_photo, missing_postal_code], integration: integration).to_xml
    doc = Nokogiri::XML(xml)
    ns = { "v" => "http://www.vivareal.com/schemas/1.0/VRSync" }
    node_text = ->(path) { doc.at_xpath(path, ns)&.text.to_s.strip }

    expect(doc.at_xpath("/v:ListingDataFeed/v:Header", ns)).to be_present
    expect(doc.at_xpath("/v:ListingDataFeed/v:Listings/v:Header", ns)).to be_nil
    expect(doc.xpath("/v:ListingDataFeed/v:Listings/v:Listing", ns).size).to eq(1)
    expect(doc.at_xpath("//v:Listing[v:ListingID='#{unsupported_photo.codigo}']", ns)).to be_nil
    expect(doc.at_xpath("//v:Listing[v:ListingID='#{missing_postal_code.codigo}']", ns)).to be_nil

    expect(node_text.call("//v:TransactionType")).to eq("Sale/Rent")
    expect(node_text.call("//v:PublicationType")).to eq("SUPER_PREMIUM")
    expect(doc.at_xpath("//v:Location", ns)["displayAddress"]).to eq("All")

    urls = doc.xpath("//v:Media/v:Item[@medium='image']", ns).map { |node| node.text.strip }
    expect(urls).to contain_exactly(
      "https://saluteimoveis.com.br/rails/active_storage/blobs/proxy/foto-1.jpg",
      "https://cdn.salute.test/foto-2.jpeg"
    )
    expect(doc.xpath("//v:Media/v:Item[@primary='true']", ns).size).to eq(1)
  ensure
    ENV["APP_HOST"] = original_app_host
  end
end

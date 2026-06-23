require "rails_helper"

RSpec.describe Portal::OpenNaventXmlSerializer do
  it "serializes Imovelweb listings using the Vista OpenNavent shape" do
    original_app_host = ENV["APP_HOST"]
    ENV["APP_HOST"] = "https://saluteimoveis.com.br"
    integration = PortalIntegration.new(
      portal: "imovelweb",
      account_id: "47540954",
      publisher_id: "publisher-ignored"
    )
    habitation = create(
      :habitation,
      codigo: "8615",
      categoria: "Apartamento",
      status: "Aluguel",
      titulo_anuncio: "Apartamento no Centro",
      descricao_web: "Descrição pública do imóvel.",
      dormitorios_qtd: 3,
      suites_qtd: 1,
      banheiros_qtd: 2,
      vagas_qtd: 1,
      elevadores_qtd: 1,
      area_total_m2: 130,
      valor_locacao_cents: 650_000,
      valor_iptu_cents: 10_000,
      tipo_publicacao_imovelweb: "destaque",
      mostrar_mapa_imovelweb: "aproximado",
      caracteristicas: ["Ar-condicionado", "Mobiliado"],
      infra_estrutura: ["Piscina"],
      pictures: [{ "url" => "/rails/active_storage/blobs/proxy/foto.jpg" }]
    )
    habitation.create_address!(
      logradouro: "Avenida Brasil",
      numero: "3618",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: "88330-239",
      latitude: -27.0046696,
      longitude: -48.6229735
    )

    xml = described_class.new(habitations: [habitation], integration: integration).to_xml
    doc = Nokogiri::XML(xml)
    node_text = ->(path) { doc.at_xpath(path).text.strip }

    expect(doc.root.name).to eq("OpenNavent")
    expect(node_text.call("//publicador/codigoImobiliaria")).to eq("47540954")
    expect(node_text.call("//codigoAnuncio")).to eq("8615")
    expect(node_text.call("//tipoPropriedade/idTipo")).to eq("2")
    expect(node_text.call("//tipoPropriedade/idSubTipo")).to eq("1")
    expect(node_text.call("//tipoPropriedade/tipo")).to eq("Apartamento")
    expect(node_text.call("//localizacao/localidade")).to eq("Centro, Balneário Camboriú, Santa Catarina, Brasil")
    expect(node_text.call("//localizacao/mostrarMapa")).to eq("APROXIMADO")
    expect(node_text.call("//precos/preco/operacao")).to eq("ALQUILER")
    expect(node_text.call("//precos/preco/quantidade")).to eq("6500")
    expect(node_text.call("//publicacao/tipoPublicacao")).to eq("DESTACADO")
    expect(node_text.call("//caracteristica[normalize-space(nome)='AR_CONDICIONADO']/valor")).to eq("1")
    expect(node_text.call("//caracteristica[normalize-space(nome)='QUARTO']/valor")).to eq("3")
    expect(node_text.call("//multimidia/imagens/imagem/urlImagem")).to eq("https://saluteimoveis.com.br/rails/active_storage/blobs/proxy/foto.jpg")
  ensure
    ENV["APP_HOST"] = original_app_host
  end
end

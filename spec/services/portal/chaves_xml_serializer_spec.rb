require "rails_helper"

RSpec.describe Portal::ChavesXmlSerializer do
  it "serializes Chaves na Mão listings using the CNM Document structure" do
    original_app_host = ENV["APP_HOST"]
    ENV["APP_HOST"] = "https://saluteimoveis.com.br"
    integration = PortalIntegration.new(portal: "chavesnamao")
    habitation = create(
      :habitation,
      categoria: "Apartamento",
      status: "Venda",
      titulo_anuncio: "Apartamento no Centro",
      descricao_web: "Descrição pública do imóvel.",
      dormitorios_qtd: 3,
      suites_qtd: 1,
      banheiros_qtd: 2,
      vagas_qtd: 1,
      area_total_m2: 130,
      area_privativa_m2: 112,
      valor_venda_cents: 1_250_000_00,
      valor_locacao_cents: 6_500_00,
      valor_condominio_cents: 950_00,
      valor_iptu_cents: 120_00,
      destaque_chaves_na_mao: "sim",
      periodo_locacao_chaves_na_mao: "por_mes",
      caracteristicas: ["Mobiliado", "Sacada"],
      infra_estrutura: ["Academia", "Piscina"],
      pictures: [
        { "url" => "/imagens/foto-1.jpg" },
        { "url" => "https://cdn.salute.test/foto-2.webp" }
      ]
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
    node_text = ->(path) { doc.at_xpath(path)&.text.to_s.strip }

    expect(xml).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
    expect(doc.root.name).to eq("Document")
    expect(doc.at_xpath("/Document/imoveis/imovel")).to be_present
    expect(doc.at_xpath("/Document/imoveis/Imovel")).to be_nil

    official_tags = %w[
      referencia codigo_cliente link_cliente titulo transacao transacao2 finalidade
      finalidade2 destaque tipo tipo2 valor valor_locacao valor_iptu valor_condominio
      area_total area_util conservacao quartos suites garagem banheiro closet salas
      despensa bar cozinha quarto_empregada escritorio area_servico lareira varanda
      lavanderia aceita_pet estado cidade bairro cep endereco numero complemento
      esconder_endereco_imovel descritivo fotos_imovel data_atualizacao latitude
      longitude video tour_360 area_comum area_privativa aceita_troca periodo_locacao
    ]
    official_tags.each do |tag|
      expect(doc.at_xpath("/Document/imoveis/imovel/#{tag}")).to be_present
    end

    expect(node_text.call("//referencia")).to eq(habitation.codigo)
    expect(node_text.call("//codigo_cliente")).to eq(habitation.codigo)
    expect(node_text.call("//link_cliente")).to start_with("https://saluteimoveis.com.br/imoveis/")
    expect(node_text.call("//transacao")).to eq("V")
    expect(node_text.call("//transacao2")).to eq("L")
    expect(node_text.call("//finalidade")).to eq("RE")
    expect(node_text.call("//destaque")).to eq("1")
    expect(node_text.call("//valor")).to eq("1250000.00")
    expect(node_text.call("//valor_locacao")).to eq("6500.00")
    expect(node_text.call("//valor_iptu")).to eq("120.00")
    expect(node_text.call("//valor_condominio")).to eq("950.00")
    expect(node_text.call("//estado")).to eq("SC")
    expect(node_text.call("//cidade")).to eq("Balneário Camboriú")
    expect(node_text.call("//descritivo")).to eq("Descrição pública do imóvel.")
    expect(node_text.call("//periodo_locacao")).to eq("1")

    first_photo = doc.at_xpath("//fotos_imovel/foto")
    expect(first_photo.at_xpath("url").text).to eq("https://saluteimoveis.com.br/imagens/foto-1.jpg")
    expect(first_photo.at_xpath("data_atualizacao").text).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
    expect(first_photo.at_xpath("principal")).to be_nil
    expect(first_photo.at_xpath("ordem")).to be_nil

    expect(doc.xpath("//area_comum/item").map(&:text)).to match_array(["Academia", "Piscina"])
    expect(doc.xpath("//area_privativa/item").map(&:text)).to include("Mobiliado", "Sacada")
  ensure
    ENV["APP_HOST"] = original_app_host
  end
end

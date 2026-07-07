require "rails_helper"

RSpec.describe Dwv::PropertyImportService do
  describe "#perform" do
    it "creates a DWV habitation with the full unit/building mapping" do
      create(:habitation, codigo: "8628", imovel_dwv: "Nao", last_sync_message: "Importado do dump Vista")

      result = described_class.new(unit_payload).perform

      habitation = result[:habitation]
      expect(habitation).to be_persisted
      expect(habitation.codigo).to eq("8629")
      expect(habitation.codigo_dwv).to eq("632439")
      expect(habitation.imovel_dwv).to eq("Sim")
      expect(habitation.status).to eq("Venda")
      expect(habitation.titulo_anuncio).to eq("Apartamento com vista mar")
      expect(habitation.nome_empreendimento).to eq("Línea")
      expect(habitation.codigo_empreendimento).to be_nil
      expect(habitation.categoria).to eq("Apartamento")
      expect(habitation.situacao).to eq("Construção")
      expect(habitation.area_privativa_m2).to eq(BigDecimal("186.0"))
      expect(habitation.area_util_m2).to eq(BigDecimal("186.0"))
      expect(habitation.valor_venda_cents).to eq(439_776_500)
      expect(habitation.dormitorios_qtd).to eq(4)
      expect(habitation.suites_qtd).to eq(4)
      expect(habitation.banheiros_qtd).to eq(5)
      expect(habitation.vagas_qtd).to eq(3)
      expect(habitation.descricao_web.to_plain_text).to include("Descrição completa do imóvel")
      expect(habitation.descricao_empreendimento).to eq("Empreendimento com lazer completo.")
      expect(habitation.infra_estrutura).to include("Piscina")
      expect(habitation.caracteristicas.values).to include("Frente mar", "Sacada com churrasqueira")
      expect(habitation.pictures.map { |pic| pic["url"] }).to include("https://cdn.dwv.test/unit-cover.jpg")
      expect(habitation.pictures.map { |pic| pic["url"] }).to include("https://cdn.dwv.test/unit-gallery-1.jpg", "https://cdn.dwv.test/unit-gallery-2.jpg")
      expect(habitation.fotos_empreendimento.map { |pic| pic["url"] }).to include("https://cdn.dwv.test/building-cover.jpg")
      expect(habitation.videos.map { |video| video["url"] }).to include("https://cdn.dwv.test/video.mp4")
      expect(habitation.plantas.map { |planta| planta["url"] }).to include("https://cdn.dwv.test/planta.jpg")
      expect(habitation.tour_virtual).to eq("https://tour.dwv.test/linea")
      expect(habitation.condicoes_negociacao).to include("Entrada: 1000000.00")
      expect(habitation.constructor.name).to eq("Rzilli")
      expect(habitation.dwv_payload).to include("id" => 632439)

      address = habitation.address
      expect(address.logradouro).to eq("2450")
      expect(address.numero).to eq("60")
      expect(address.bairro).to eq("Centro")
      expect(address.cidade).to eq("Balneário Camboriú")
      expect(address.uf).to eq("SC")
      expect(address.cep).to eq("88330-410")
      expect(address.imediacoes).to eq(["A 30m da Av. Brasil"])
    end

    it "only updates price, availability and sync metadata on an existing DWV record" do
      create(:habitation, codigo: "8628", imovel_dwv: "Nao", last_sync_message: "Importado do dump Vista")
      habitation = create(
        :habitation,
        codigo: "DWV-632439",
        codigo_dwv: "632439",
        imovel_dwv: "Sim",
        titulo_anuncio: "Título revisado manualmente",
        descricao_web: "Descrição revisada manualmente.",
        pictures: [{ "url" => "https://cdn.local/manual.jpg" }],
        area_privativa_m2: BigDecimal("150.0"),
        dormitorios_qtd: 2,
        valor_venda_cents: 390_000_000,
        status: "Suspenso",
        exibir_no_site_flag: false
      )
      habitation.create_address!(
        logradouro: "Rua Manual",
        numero: "10",
        bairro: "Manual",
        cidade: "Balneário Camboriú",
        uf: "SC"
      )

      described_class.new(unit_payload).perform
      habitation.reload

      expect(habitation.codigo).to eq("8629")
      expect(habitation.valor_venda_cents).to eq(439_776_500)
      expect(habitation.status).to eq("Venda")
      expect(habitation.exibir_no_site_flag).to eq(true)
      expect(habitation.titulo_anuncio).to eq("Título revisado manualmente")
      expect(habitation.descricao_web.to_plain_text).to include("Descrição revisada manualmente")
      expect(habitation.area_privativa_m2).to eq(BigDecimal("150.0"))
      expect(habitation.dormitorios_qtd).to eq(2)
      expect(habitation.pictures).to eq([{ "url" => "https://cdn.local/manual.jpg" }])
      expect(habitation.address.logradouro).to eq("Rua Manual")
      expect(habitation.last_sync_message).to eq("Sincronizado via DWV (valor e disponibilidade)")
      expect(habitation.dwv_payload).to include("id" => 632439)
    end

    it "deactivates an existing DWV record when the property payload is deleted" do
      dwv_id = "DEL-#{SecureRandom.hex(6)}"
      habitation = create(
        :habitation,
        codigo: "DWV-DEL-#{SecureRandom.hex(4)}",
        codigo_dwv: dwv_id,
        imovel_dwv: "Sim",
        titulo_anuncio: "Imóvel removido na DWV"
      )

      result = described_class.new("data" => { "id" => dwv_id, "deleted" => true }).perform

      expect(result[:deleted]).to eq(true)
      expect(result[:habitation]).to eq(habitation)
      habitation.reload
      expect(habitation.status).to eq("Suspenso")
      expect(habitation.motivo_suspensao).to eq("Removido na DWV")
      expect(habitation.exibir_no_site_flag).to eq(false)
      expect(habitation.last_sync_message).to eq("Marcado como removido na DWV")
    end

    it "maps auto inactive without sold value as suspended" do
      dwv_id = "AUTO-#{SecureRandom.hex(6)}"
      habitation = create(
        :habitation,
        codigo: "DWV-AUTO-#{SecureRandom.hex(4)}",
        codigo_dwv: dwv_id,
        imovel_dwv: "Sim",
        status: "Venda",
        valor_venda_cents: 0
      )

      described_class.new(
        "data" => {
          "id" => dwv_id,
          "integration_status" => "auto_inactive",
          "deleted" => false,
          "reference" => habitation.codigo
        }
      ).perform

      habitation.reload
      expect(habitation.status).to eq("Suspenso")
      expect(habitation.motivo_suspensao).to eq("Inativado na DWV")
      expect(habitation.exibir_no_site_flag).to eq(false)
    end

    it "does not destroy a non-DWV record when a deleted DWV payload has the same external code" do
      habitation = create(
        :habitation,
        codigo_dwv: "632439",
        imovel_dwv: "Não",
        titulo_anuncio: "Cadastro manual com código externo legado"
      )

      result = described_class.new("data" => { "id" => 632439, "deleted" => true }).perform

      expect(result[:deleted]).to eq(true)
      expect(result[:habitation]).to be_nil
      expect(Habitation.exists?(habitation.id)).to eq(true)
    end

    it "links units to a DWV development by the internal DWV code while keeping the local reference" do
      create(
        :habitation,
        tipo: "Empreendimento",
        categoria: "Empreendimento",
        codigo: "9000",
        codigo_dwv: "9001",
        imovel_dwv: "Sim",
        nome_empreendimento: "Línea"
      )

      result = described_class.new(unit_payload).perform

      expect(result[:habitation].codigo_empreendimento).to eq("9000")
    end

    it "maps third party property fields without requiring unit data" do
      result = described_class.new(third_party_payload).perform
      habitation = result[:habitation]

      expect(habitation.status).to eq("Aluguel")
      expect(habitation.categoria).to eq("Casa")
      expect(habitation.titulo_anuncio).to eq("Casa para locação")
      expect(habitation.nome_empreendimento).to be_blank
      expect(habitation.valor_locacao_cents).to eq(12_000_00)
      expect(habitation.valor_condominio_cents).to eq(450_00)
      expect(habitation.valor_iptu_cents).to eq(180_00)
      expect(habitation.area_privativa_m2).to eq(BigDecimal("220.0"))
      expect(habitation.dormitorios_qtd).to eq(3)
      expect(habitation.pictures.map { |pic| pic["url"] }).to include("https://cdn.dwv.test/casa.jpg")
      expect(habitation.address.logradouro).to eq("1000")
      expect(habitation.address.numero).to eq("55")
      expect(habitation.address.complemento).to eq("Casa 2")
    end

    it "maps third party apartment title as development name when it is not an ad title" do
      result = described_class.new(third_party_apartment_payload).perform
      habitation = result[:habitation]

      expect(habitation.categoria).to eq("Apartamento")
      expect(habitation.nome_empreendimento).to eq("La Madeson")
      expect(habitation.titulo_anuncio).to be_blank
      expect(habitation.display_title).to eq("Apartamento 3 dormitórios em Centro Balneário Camboriú")
      expect(habitation.address.complemento).to eq("Apartamento 604")
    end
  end

  def unit_payload
    {
      "data" => {
        "id" => 632439,
        "status" => "active",
        "deleted" => false,
        "title" => "Apartamento com vista mar",
        "advertisement_title" => "Apartamento com vista mar",
        "description_text" => "Descrição completa do imóvel.",
        "construction_stage_raw" => "under construction",
        "inserted_at" => "2026-01-10T10:00:00-03:00",
        "last_updated_at" => "2026-06-08T14:15:00-03:00",
        "unit" => {
          "title" => "901",
          "type" => "Apartamento",
          "price" => "4397765.00",
          "private_area" => "186.0",
          "util_area" => "186.0",
          "total_area" => "0.0",
          "dorms" => 4,
          "suites" => 4,
          "bathroom" => 5,
          "parking_spaces" => 3,
          "cover" => { "url" => "https://cdn.dwv.test/unit-cover.jpg" },
          "payment_conditions" => [
            { "name" => "Entrada", "price" => "1000000.00" }
          ],
          "additional_galleries" => [
            {
              "files" => [
                { "url" => "https://cdn.dwv.test/unit-gallery-1.jpg" },
                { "url" => "https://cdn.dwv.test/unit-gallery-2.jpg" }
              ]
            }
          ],
          "floor_plan" => {
            "category" => { "title" => "Apartamento", "tag" => "Residencial" },
            "images" => [{ "url" => "https://cdn.dwv.test/planta.jpg" }]
          }
        },
        "building" => {
          "id" => 9001,
          "title" => "Línea",
          "description" => "<p>Empreendimento com lazer completo.</p>",
          "delivery_date" => "2029-06-01",
          "cover" => { "url" => "https://cdn.dwv.test/building-cover.jpg" },
          "gallery" => [{ "url" => "https://cdn.dwv.test/building-gallery.jpg" }],
          "videos" => [{ "url" => "https://cdn.dwv.test/video.mp4" }],
          "virtual_tour" => "https://tour.dwv.test/linea",
          "features" => [
            { "title" => "Piscina", "type" => "Empreendimento" },
            { "title" => "Frente Mar", "type" => "Apartamento" },
            { "title" => "Sacada com churrasqueira", "type" => "Apartamento" }
          ],
          "address" => {
            "street_name" => "Rua 2450",
            "street_number" => "60",
            "neighborhood" => "Centro",
            "city" => "Balneário Camboriú",
            "state" => "SC",
            "zip_code" => "88330-410",
            "country" => "Brasil",
            "complement" => "A 30m da Av. Brasil",
            "latitude" => "-26.9900000",
            "longitude" => "-48.6300000"
          }
        },
        "construction_company" => {
          "title" => "Rzilli",
          "site" => "https://rzilli.test"
        }
      }
    }
  end

  def third_party_payload
    {
      "data" => {
        "id" => 620000,
        "status" => "active",
        "deleted" => false,
        "third_party_property" => {
          "title" => "Casa para locação",
          "type" => "Casa",
          "rent" => "12000.00",
          "property_tax" => "180.00",
          "administration_fee" => "450.00",
          "private_area" => "220.0",
          "dorms" => 3,
          "suites" => 1,
          "bathroom" => 2,
          "parking_spaces" => 2,
          "unit_info" => "Casa 2",
          "cover" => { "url" => "https://cdn.dwv.test/casa.jpg" },
          "address" => {
            "street_name" => "Rua 1000",
            "street_number" => "55",
            "neighborhood" => "Centro",
            "city" => "Itapema",
            "state" => "SC",
            "zip_code" => "88220-000"
          }
        }
      }
    }
  end

  def third_party_apartment_payload
    {
      "data" => {
        "id" => 644692,
        "title" => "La Madeson",
        "advertisement_title" => "La Madeson",
        "status" => "active",
        "deleted" => false,
        "third_party_property" => {
          "title" => "La Madeson",
          "type" => "Apartamento",
          "price" => "1850000.00",
          "private_area" => "122.0",
          "dorms" => 3,
          "suites" => 3,
          "bathroom" => 4,
          "parking_spaces" => 2,
          "unit_info" => "Apartamento 604",
          "cover" => { "url" => "https://cdn.dwv.test/la-madeson.jpg" },
          "address" => {
            "street_name" => "Rua 1131",
            "street_number" => "101",
            "neighborhood" => "Centro",
            "city" => "Balneário Camboriú",
            "state" => "SC",
            "zip_code" => "88330-786"
          }
        }
      }
    }
  end
end

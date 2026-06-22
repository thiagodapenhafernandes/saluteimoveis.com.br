require "rails_helper"

RSpec.describe Habitation, type: :model do
  describe ".next_automatic_codigo" do
    it "continues the CRM sequence after the highest imported Vista reference" do
      create(:habitation, codigo: "8628", imovel_dwv: "Nao", last_sync_message: "Importado do dump Vista")
      create(:habitation, codigo: "DWV-9999", imovel_dwv: "Sim")

      expect(described_class.next_automatic_codigo).to eq("8629")
    end

    it "skips numeric codes that are already occupied" do
      create(:habitation, codigo: "8628", imovel_dwv: "Nao", last_sync_message: "Importado do dump Vista")
      create(:habitation, codigo: "8629", imovel_dwv: "Nao")

      expect(described_class.next_automatic_codigo).to eq("8630")
    end
  end

  describe "#assign_codigo_automaticamente" do
    it "fills blank codigo with the next CRM sequence value on create" do
      create(:habitation, codigo: "8628", imovel_dwv: "Nao", last_sync_message: "Importado do dump Vista")

      habitation = described_class.create!(categoria: "Apartamento")

      expect(habitation.codigo).to eq("8629")
    end
  end

  describe "#data_cadastro_crm" do
    it "sets the registration date on create when it is blank" do
      habitation = described_class.create!(categoria: "Apartamento")

      expect(habitation.data_cadastro_crm).to be_present
    end

    it "keeps an imported registration date when present" do
      imported_at = 3.years.ago.change(usec: 0)
      habitation = described_class.create!(categoria: "Apartamento", data_cadastro_crm: imported_at)

      expect(habitation.data_cadastro_crm.to_i).to eq(imported_at.to_i)
    end
  end

  describe "#display_title" do
    it "replaces a conflicting neighborhood from imported titles with the current neighborhood" do
      habitation = described_class.new(
        titulo_anuncio: "Casa para alugar com 3 suítes na Barra Sul",
        bairro: "Pioneiros",
        categoria: "Casa"
      )

      expect(habitation.display_title).to eq("Casa para alugar com 3 suítes em Pioneiros")
    end

    it "keeps the imported title when its neighborhood matches the record" do
      habitation = described_class.new(
        titulo_anuncio: "Apartamento para venda na Barra Sul",
        bairro: "Barra Sul",
        categoria: "Apartamento"
      )

      expect(habitation.display_title).to eq("Apartamento para venda na Barra Sul")
    end

    it "does not replace the property city with the neighborhood in imported titles" do
      habitation = described_class.new(
        titulo_anuncio: "Galpão para aluguel anual Tabuleiro em Camboriú",
        bairro: "Tabuleiro",
        cidade: "Camboriú",
        categoria: "Galpão"
      )

      expect(habitation.display_title).to eq("Galpão para aluguel anual Tabuleiro em Camboriú")
    end
  end

  describe "#admin_card_title" do
    it "ignores unlinked standalone development names on admin cards" do
      habitation = described_class.new(
        categoria: "Casa",
        titulo_anuncio: "Casa para locação no Centro",
        nome_empreendimento: "Torre de Mallorca",
        codigo_empreendimento: "1027"
      )

      expect(habitation.display_development_name).to be_nil
      expect(habitation.admin_card_title).to eq("Casa para locação no Centro")
    end

    it "keeps development names for apartment units" do
      habitation = described_class.new(
        categoria: "Apartamento",
        titulo_anuncio: "Apartamento no Centro",
        nome_empreendimento: "Torre de Mallorca"
      )

      expect(habitation.display_development_name).to eq("Torre de Mallorca")
      expect(habitation.admin_card_title).to eq("Torre de Mallorca")
    end

    it "falls back when a standalone property title conflicts with its category" do
      habitation = described_class.new(
        categoria: "Casa",
        titulo_anuncio: "Sala comercial aluguel anual no Centro",
        dormitorios_qtd: 5,
        bairro: "Condomínio Caledônia",
        cidade: "Camboriú"
      )

      expect(habitation).to be_title_category_inconsistent
      expect(habitation.admin_card_title).to eq("Casa 5 dormitórios em Condomínio Caledônia")
    end
  end

  describe "#address_complement_label" do
    it "uses apartment label only for apartment-like units" do
      expect(described_class.new(categoria: "Apartamento").address_complement_label).to eq("Apto.")
      expect(described_class.new(categoria: "Casa").address_complement_label).to eq("Compl.")
      expect(described_class.new(categoria: "Galpão").address_complement_label).to eq("Compl.")
    end
  end

  describe "standalone development cleanup" do
    it "clears unlinked development names from standalone warehouses" do
      habitation = create(:habitation, categoria: "Galpão", nome_empreendimento: "Torre Indevida", codigo_empreendimento: nil)

      expect(habitation.reload.nome_empreendimento).to be_nil
    end
  end

  describe "third-party commercial values" do
    it "stores formatted third-party values in cents" do
      habitation = described_class.new(
        valor_alugado_terceiros_formatted: "R$ 4.500,00",
        valor_vendido_terceiros_formatted: "R$ 980.000,00"
      )

      expect(habitation.valor_alugado_terceiros_cents).to eq(450_000)
      expect(habitation.valor_vendido_terceiros_cents).to eq(98_000_000)
    end
  end

  describe "#display_area_m2" do
    it "uses private area for residential units when total area is zero" do
      habitation = create(:habitation, categoria: "Apartamento", area_total_m2: 0, area_privativa_m2: 130)

      expect(habitation.display_area_m2).to eq(130)
      expect(habitation.area_formatted).to eq("130 m²")
      expect(habitation.card_data[:area]).to eq(130)
      expect(habitation.structured_data[:floorSize][:value]).to eq(130.0)
    end

    it "uses total area first for land properties" do
      habitation = described_class.new(categoria: "Terreno", area_total_m2: 450, area_privativa_m2: 130)

      expect(habitation.display_area_m2).to eq(450)
    end
  end

  describe "#inactive_for_admin_card?" do
    it "does not mark active internal properties as inactive cards" do
      habitation = described_class.new(status: "Aluguel", exibir_no_site_flag: false)

      expect(habitation).not_to be_inactive_for_admin_card
    end

    it "marks unavailable statuses as inactive cards" do
      expect(described_class.new(status: "Suspenso", exibir_no_site_flag: true)).to be_inactive_for_admin_card
      expect(described_class.new(status: "Vendido terceiros", exibir_no_site_flag: true)).to be_inactive_for_admin_card
      expect(described_class.new(status: "Alugado imobiliária", exibir_no_site_flag: true)).to be_inactive_for_admin_card
    end
  end

  describe "intake visit note fields" do
    it "stores owner city and visit days inside structured visit notes" do
      habitation = described_class.new(observacoes_visitas: "Senha do imóvel: 123")

      habitation.proprietario_cidade = "Itajaí"
      habitation.dias_visitas = "Seg manhã, Qua tarde"

      expect(habitation.proprietario_cidade).to eq("Itajaí")
      expect(habitation.dias_visitas).to eq(["Seg manhã", "Qua tarde"])
      expect(habitation.observacoes_visitas).to include("Senha do imóvel: 123")
      expect(habitation.observacoes_visitas).to include("Cidade do proprietário: Itajaí")
      expect(habitation.observacoes_visitas).to include("Dias/horários para visita: Seg manhã, Qua tarde")
    end
  end

  describe "#intake_missing_requirements" do
    it "accepts address complement as the apartment unit number" do
      habitation = build(:habitation, categoria: "Apartamento", bloco: "")
      habitation.ensure_address.complemento = "101"

      expect(habitation).to be_requires_unit_number
      expect(habitation).to be_intake_unit_number_present
      expect(habitation.intake_missing_requirements).not_to include("Número da unidade")
    end

    it "uses the linked proprietor city for owner data requirements" do
      proprietor = build(:proprietor, city: "Balneário Camboriú")
      habitation = build(:habitation, proprietor: proprietor, proprietario: "Hans", proprietario_celular: "(47) 99999-0000")

      expect(habitation.proprietario_cidade).to eq("Balneário Camboriú")
      expect(habitation.intake_missing_requirements).not_to include("Dados do proprietário")
    end

    it "does not require proprietor city for administrative property review when a linked proprietor has contact data" do
      proprietor = build(:proprietor, city: nil, phone_primary: "(47) 99601-2553", email: nil)
      habitation = build(:habitation, proprietor: proprietor, proprietario: nil, proprietario_celular: nil, proprietario_email: nil)

      expect(habitation.intake_missing_requirements).not_to include("Dados do proprietário")
    end

    it "keeps proprietor city required for broker intake submission" do
      proprietor = build(:proprietor, city: nil, phone_primary: "(47) 99601-2553", email: nil)
      habitation = build(:habitation, proprietor: proprietor, proprietario: nil, proprietario_celular: nil, proprietario_email: nil)

      expect(habitation.intake_missing_requirements(require_owner_city: true)).to include("Dados do proprietário")
    end

    it "accepts manual visit notes without treating technical note lines as visit availability" do
      technical_notes = described_class.new(observacoes_visitas: "Cidade do proprietário: Itajaí")
      manual_notes = described_class.new(observacoes_visitas: "Proprietário libera acesso com a portaria")

      expect(technical_notes).not_to be_intake_visit_days_present
      expect(manual_notes).to be_intake_visit_days_present
    end

    it "does not require condo or IPTU for commercial, warehouse and land intakes" do
      %w[Sala\ Comercial Galpão Terreno].each do |category|
        habitation = build(:habitation, categoria: category, valor_condominio_cents: nil, valor_iptu_cents: nil)

        expect(habitation.intake_missing_requirements).not_to include("Financeiro e valores")
      end
    end

    it "keeps condo or IPTU required for residential intakes" do
      habitation = build(:habitation, categoria: "Apartamento", valor_condominio_cents: nil, valor_iptu_cents: nil)

      expect(habitation.intake_missing_requirements).to include("Financeiro e valores")
    end

    it "does not require key location for land intakes" do
      habitation = build(:habitation, categoria: "Terreno", key_location: nil)

      expect(habitation.intake_missing_requirements).not_to include("Chaves")
    end

    it "keeps key location required for non-land intakes" do
      habitation = build(:habitation, categoria: "Apartamento", key_location: nil)

      expect(habitation.intake_missing_requirements).to include("Chaves")
    end
  end

  describe "#rental_guarantee_method=" do
    it "normalizes multiple guarantee methods into a compatible string" do
      habitation = build(:habitation, rental_guarantee_method: ["Seguro fiança", "", "Caução", "Seguro fiança"])

      expect(habitation.rental_guarantee_method).to eq("Seguro fiança, Caução")
      expect(habitation.rental_guarantee_methods).to eq(["Seguro fiança", "Caução"])
      expect(habitation).to be_valid
    end

    it "rejects invalid guarantee methods inside the list" do
      habitation = build(:habitation, rental_guarantee_method: ["Seguro fiança", "Garantia inválida"])

      expect(habitation).not_to be_valid
      expect(habitation.errors[:rental_guarantee_method]).to include("possui opção inválida")
    end
  end

  describe "category-aware slugs" do
    it "regenerates a code-based slug when it no longer matches the current category" do
      habitation = create(
        :habitation,
        codigo: "8546",
        categoria: "Apartamento",
        cidade: "Balneário Camboriú",
        bairro: "Centro",
        slug: "apartamento-balneario-camboriu-centro-8546"
      )
      habitation.update_columns(slug: "sobrado-8546")

      habitation.update!(titulo_anuncio: "Apartamento no Centro")

      expect(habitation.reload.slug).to eq("apartamento-balneario-camboriu-centro-8546")
    end

    it "keeps a code-based slug that already matches the current category" do
      habitation = create(
        :habitation,
        codigo: "8546",
        categoria: "Apartamento",
        cidade: "Balneário Camboriú",
        bairro: "Centro",
        slug: "apartamento-balneario-camboriu-centro-8546"
      )

      habitation.update!(titulo_anuncio: "Apartamento atualizado")

      expect(habitation.reload.slug).to eq("apartamento-balneario-camboriu-centro-8546")
    end

    it "does not change existing image data while fixing a mismatched slug" do
      habitation = create(
        :habitation,
        codigo: "8546",
        categoria: "Apartamento",
        cidade: "Balneário Camboriú",
        bairro: "Centro",
        slug: "apartamento-balneario-camboriu-centro-8546",
        pictures: []
      )
      habitation.photos.attach(
        io: StringIO.new("\x89PNG\r\n\x1A\n".b),
        filename: "foto.png",
        content_type: "image/png"
      )
      photo_ids_order = habitation.photos.attachments.pluck(:id)
      pictures = [
        {
          "url" => "https://cdn.example.com/imoveis/8546/foto-vista.jpg",
          "ordem" => 1,
          "principal" => true
        }
      ]
      habitation.update_columns(
        slug: "sobrado-8546",
        pictures: pictures,
        photo_ids_order: photo_ids_order
      )

      habitation.reload.update!(titulo_anuncio: "Apartamento com fotos preservadas")

      habitation.reload
      expect(habitation.slug).to eq("apartamento-balneario-camboriu-centro-8546")
      expect(habitation.photos.attachments.pluck(:id)).to eq(photo_ids_order)
      expect(habitation.pictures).to eq(pictures)
      expect(habitation.photo_ids_order).to eq(photo_ids_order)
    end
  end

  describe "development name hierarchy" do
    it "clears standalone house development names when there is no linked development code" do
      habitation = described_class.new(
        categoria: "Casa",
        codigo_empreendimento: "",
        nome_empreendimento: "Albatroz"
      )

      habitation.validate

      expect(habitation.codigo_empreendimento).to be_nil
      expect(habitation.nome_empreendimento).to be_nil
    end

    it "keeps apartment development names even before a development code is linked" do
      habitation = described_class.new(
        categoria: "Apartamento",
        codigo_empreendimento: "",
        nome_empreendimento: "Residencial Teste"
      )

      habitation.validate

      expect(habitation.nome_empreendimento).to eq("Residencial Teste")
    end

    it "keeps condominium house development names even before a development code is linked" do
      habitation = described_class.new(
        categoria: "Casa em Condomínio",
        codigo_empreendimento: "",
        nome_empreendimento: "Condomínio Teste"
      )

      habitation.validate

      expect(habitation.nome_empreendimento).to eq("Condomínio Teste")
    end

    it "uses the linked development name when a standalone house has a valid development code" do
      parent = create(
        :habitation,
        tipo: "Empreendimento",
        categoria: "Empreendimento",
        codigo: "9901",
        nome_empreendimento: "Residencial Correto"
      )
      habitation = described_class.new(
        categoria: "Casa",
        codigo_empreendimento: parent.codigo,
        nome_empreendimento: "Albatroz"
      )

      habitation.validate

      expect(habitation.nome_empreendimento).to eq("Residencial Correto")
    end
  end

  describe "#unavailable_for_duplicate_check?" do
    it "keeps hidden-from-site properties unavailable for duplicate blocking" do
      habitation = described_class.new(status: "Aluguel", exibir_no_site_flag: false)

      expect(habitation).to be_unavailable_for_duplicate_check
    end
  end

  describe "#capture_price_reductions" do
    it "stores previous sale price and promotional value when sale price decreases" do
      habitation = create(:habitation, valor_venda_cents: 1_000_000_00, valor_promocional_cents: nil)

      habitation.update!(valor_venda_cents: 900_000_00)

      expect(habitation).to have_attributes(
        valor_venda_anterior_cents: 1_000_000_00,
        valor_promocional_cents: 900_000_00
      )
    end

    it "stores previous rent price and promotional value when rent price decreases" do
      habitation = create(:habitation, valor_venda_cents: 0, valor_locacao_cents: 6_000_00, valor_promocional_cents: nil)

      habitation.update!(valor_locacao_cents: 5_500_00)

      expect(habitation).to have_attributes(
        valor_locacao_anterior_cents: 6_000_00,
        valor_promocional_cents: 5_500_00
      )
    end
  end

  describe "exigência de vaga na ficha de cadastro" do
    it "exige tipo de vaga e vagas para apartamento" do
      habitation = build(:habitation, categoria: "Apartamento", tipo_vaga: nil, vagas_qtd: nil)

      expect(habitation.requires_parking_info?).to be(true)
      missing = habitation.intake_missing_requirements
      expect(missing).to include("Tipo de vaga")
      expect(missing).to include("Vaga de garagem")
    end

    it "também exige para cobertura, loft e studio" do
      %w[Cobertura Loft Studio].each do |categoria|
        habitation = build(:habitation, categoria: categoria)
        expect(habitation.requires_parking_info?).to be(true), "esperava obrigatório para #{categoria}"
      end
    end

    it "não exige vaga para casa, galpão, terreno e sala comercial" do
      ["Casa", "Galpão", "Terreno", "Sala Comercial"].each do |categoria|
        habitation = build(:habitation, categoria: categoria, tipo_vaga: nil, vagas_qtd: nil)

        expect(habitation.requires_parking_info?).to be(false), "esperava opcional para #{categoria}"
        missing = habitation.intake_missing_requirements
        expect(missing).not_to include("Tipo de vaga"), "#{categoria} não deveria exigir tipo de vaga"
        expect(missing).not_to include("Vaga de garagem"), "#{categoria} não deveria exigir vaga"
      end
    end
  end

  describe "#display_title com bairro comercial" do
    it "preserva o bairro do título salvo usando o bairro comercial, sem trocar pelo bairro interno" do
      habitation = create(:habitation, categoria: "Apartamento", titulo_anuncio: "Apartamento diferenciado aluguel anual 4 suítes na Barra Sul")
      Address.create!(
        addressable: habitation,
        tipo_endereco: "Rua",
        logradouro: "Rua X",
        numero: "1",
        bairro: "Centro",
        bairro_comercial: "Barra Sul",
        cidade: "Balneário Camboriú",
        uf: "SC"
      )
      habitation.reload

      expect(habitation.display_title).to eq("Apartamento diferenciado aluguel anual 4 suítes na Barra Sul")
      expect(habitation.display_title).not_to include("em Centro")
    end
  end

  describe "campos de valor formatados (limpar)" do
    it "limpa o valor quando recebe em branco (apagar e salvar persiste)" do
      habitation = create(:habitation, valor_venda_cents: 500_000_00)

      habitation.update!(valor_venda_formatted: "")

      expect(habitation.reload.valor_venda_cents).to be_nil
    end

    it "continua convertendo um valor preenchido" do
      habitation = create(:habitation, valor_venda_cents: 0)

      habitation.update!(valor_venda_formatted: "R$ 1.234,56")

      expect(habitation.reload.valor_venda_cents).to eq(123_456)
    end
  end

  describe "permuta (captação)" do
    it "marca aceita_permuta_flag quando algum flag específico está marcado" do
      habitation = create(:habitation, aceita_permuta_veiculo_flag: true)

      expect(habitation.reload.aceita_permuta_flag).to be(true)
    end

    it "aceita valor da permuta formatado e porcentagem" do
      habitation = create(:habitation)

      habitation.update!(valor_aceito_permuta: "R$ 50.000,00", permuta_valor_percentual: 20)

      expect(habitation.reload.valor_aceito_permuta_cents).to eq(5_000_000)
      expect(habitation.permuta_valor_percentual).to eq(20)
    end
  end

  describe "#uses_building_infrastructure?" do
    it "vale para apartamento e casa em condomínio, mas não para casa de rua/terreno" do
      expect(build(:habitation, categoria: "Apartamento").uses_building_infrastructure?).to be(true)
      expect(build(:habitation, categoria: "Casa em Condomínio").uses_building_infrastructure?).to be(true)
      expect(build(:habitation, categoria: "Casa").uses_building_infrastructure?).to be(false)
      expect(build(:habitation, categoria: "Terreno").uses_building_infrastructure?).to be(false)
    end
  end

  describe "#display_neighborhood" do
    def build_with_address(bairro:, bairro_comercial:)
      habitation = create(:habitation)
      Address.create!(
        addressable: habitation,
        tipo_endereco: "Rua",
        logradouro: "2000",
        numero: "120",
        bairro: bairro,
        bairro_comercial: bairro_comercial,
        cidade: "Balneário Camboriú",
        uf: "SC",
        cep: "88330-590"
      )
      habitation.reload
    end

    it "prefere o bairro comercial quando preenchido" do
      habitation = build_with_address(bairro: "Centro", bairro_comercial: "Barra Sul")

      expect(habitation.display_neighborhood).to eq("Barra Sul")
    end

    it "recai para o bairro comum quando o comercial está vazio" do
      habitation = build_with_address(bairro: "Centro", bairro_comercial: "")

      expect(habitation.display_neighborhood).to eq("Centro")
    end

    it "ignora o placeholder '.' do bairro comercial" do
      habitation = build_with_address(bairro: "Centro", bairro_comercial: ".")

      expect(habitation.display_neighborhood).to eq("Centro")
    end
  end
end

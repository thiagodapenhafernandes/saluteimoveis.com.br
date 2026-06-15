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
end

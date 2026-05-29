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
end

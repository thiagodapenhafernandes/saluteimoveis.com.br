require "rails_helper"

RSpec.describe Proprietor, type: :model do
  describe "unicidade de CPF/CNPJ" do
    it "bloqueia um segundo proprietário com o mesmo CPF/CNPJ" do
      create(:proprietor, cpf_cnpj: "123.456.789-00")

      duplicate = build(:proprietor, cpf_cnpj: "123.456.789-00")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:cpf_cnpj]).to include("já cadastrado para outro proprietário")
    end

    it "considera duplicado mesmo com máscara diferente (compara só os dígitos)" do
      create(:proprietor, cpf_cnpj: "123.456.789-00")

      duplicate = build(:proprietor, cpf_cnpj: "12345678900")

      expect(duplicate).not_to be_valid
    end

    it "permite vários proprietários sem CPF/CNPJ" do
      create(:proprietor, cpf_cnpj: nil)

      expect(build(:proprietor, cpf_cnpj: "")).to be_valid
    end

    it "permite salvar o mesmo registro novamente (não conflita consigo mesmo)" do
      proprietor = create(:proprietor, cpf_cnpj: "123.456.789-00")

      proprietor.name = "Nome atualizado"

      expect(proprietor).to be_valid
    end

    it "isenta registros gerenciados pelo Vista (com vista_code)" do
      create(:proprietor, cpf_cnpj: "123.456.789-00")

      from_vista = build(:proprietor, cpf_cnpj: "123.456.789-00", vista_code: "C-9999")

      expect(from_vista).to be_valid
    end
  end

  describe "cidade obrigatória (contexto :manual)" do
    it "exige cidade no cadastro manual" do
      proprietor = build(:proprietor, city: nil)

      expect(proprietor.valid?(:manual)).to be(false)
      expect(proprietor.errors[:city]).to include("é obrigatória")
    end

    it "aceita cadastro manual com cidade" do
      expect(build(:proprietor, city: "Itajaí").valid?(:manual)).to be(true)
    end

    it "não exige cidade fora do contexto manual (quick-create / Vista)" do
      expect(build(:proprietor, city: nil).valid?).to be(true)
    end
  end

  describe ".find_by_phone" do
    it "encontra por qualquer telefone comparando só os dígitos" do
      proprietor = create(:proprietor, phone_primary: nil, mobile_phone: "(47) 98888-1234")

      expect(Proprietor.find_by_phone("47988881234")).to eq(proprietor)
      expect(Proprietor.find_by_phone("(47) 98888-1234")).to eq(proprietor)
    end

    it "retorna nil quando não encontra" do
      expect(Proprietor.find_by_phone("47900000000")).to be_nil
    end
  end
end

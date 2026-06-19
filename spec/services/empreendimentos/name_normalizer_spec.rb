require "rails_helper"

RSpec.describe Empreendimentos::NameNormalizer do
  describe ".key" do
    it "agrupa variantes do mesmo empreendimento na mesma chave" do
      key = described_class.key("Grand Place")
      expect(described_class.key("Edifício Grand Place")).to eq(key)
      expect(described_class.key("Grand Place Tower")).to eq(key)
      expect(described_class.key("Edifício Grand Place Tower")).to eq(key)
      expect(described_class.key("Residencial Grand Place")).to eq(key)
    end

    it "ignora acentos e pontuação" do
      expect(described_class.key("Viña Del Mar")).to eq(described_class.key("Vina Del Mar"))
      expect(described_class.key("Maria Victória")).to eq(described_class.key("Maria Victoria"))
    end

    it "mantém empreendimentos diferentes em chaves diferentes" do
      expect(described_class.key("Grand Place")).not_to eq(described_class.key("Grand Palazzo"))
    end
  end

  describe ".canonical_for" do
    it "escolhe o mais frequente" do
      names = ["Edifício Grand Place", "Grand Place"]
      counts = { "Edifício Grand Place" => 2, "Grand Place" => 10 }
      expect(described_class.canonical_for(names, counts: counts)).to eq("Grand Place")
    end

    it "desempata pelo mais descritivo (mais longo)" do
      names = ["Grand Place", "Edifício Grand Place"]
      expect(described_class.canonical_for(names)).to eq("Edifício Grand Place")
    end
  end
end

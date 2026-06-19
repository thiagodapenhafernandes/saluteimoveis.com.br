require "rails_helper"

RSpec.describe Empreendimentos::NameNormalizationService do
  def apto(nome)
    create(:habitation, categoria: "Apartamento", codigo: "U-#{SecureRandom.hex(4)}", nome_empreendimento: nome)
  end

  it "agrupa variantes em DRY-RUN sem alterar o banco" do
    create(:habitation, tipo: "Empreendimento", categoria: "Empreendimento", codigo: "EMP-#{SecureRandom.hex(4)}", nome_empreendimento: "Grand Place")
    u1 = apto("Edifício Grand Place")
    u2 = apto("Grand Place Tower")

    result = described_class.new.call

    cluster = result.clusters.find { |c| c[:key] == Empreendimentos::NameNormalizer.key("Grand Place") }
    expect(cluster).to be_present
    expect(cluster[:canonical]).to eq("Grand Place")
    expect(result.records_updated).to eq(0)
    expect(u1.reload.nome_empreendimento).to eq("Edifício Grand Place")
    expect(u2.reload.nome_empreendimento).to eq("Grand Place Tower")
  end

  it "unifica as variantes para o nome canônico em APPLY, sem fundir empreendimentos diferentes" do
    create(:habitation, tipo: "Empreendimento", categoria: "Empreendimento", codigo: "EMP-#{SecureRandom.hex(4)}", nome_empreendimento: "Grand Place")
    u1 = apto("Edifício Grand Place")
    u2 = apto("Grand Place Tower")
    u3 = apto("Edifício Grand Place Tower")
    outro = apto("Grand Palazzo")

    described_class.new(apply: true).call

    expect([u1, u2, u3].map { |h| h.reload.nome_empreendimento }).to all(eq("Grand Place"))
    expect(outro.reload.nome_empreendimento).to eq("Grand Palazzo")
  end

  it "aplica a partir de um CSV revisado (variante -> nome_canonico)" do
    u1 = apto("Edifício Bela Vista")
    u2 = apto("Bela Vista Tower")
    keep = apto("Outro Lugar")

    require "csv"
    path = Rails.root.join("tmp", "reports", "teste_normalizacao_#{SecureRandom.hex(4)}.csv")
    CSV.open(path, "w") do |csv|
      csv << %w[chave nome_canonico variante registros]
      csv << ["bela vista", "Residencial Bela Vista", "Edifício Bela Vista", 1]
      csv << ["bela vista", "Residencial Bela Vista", "Bela Vista Tower", 1]
    end

    summary = described_class.apply_from_csv(path.to_s)

    expect(summary[:records_updated]).to eq(2)
    expect(u1.reload.nome_empreendimento).to eq("Residencial Bela Vista")
    expect(u2.reload.nome_empreendimento).to eq("Residencial Bela Vista")
    expect(keep.reload.nome_empreendimento).to eq("Outro Lugar")
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end

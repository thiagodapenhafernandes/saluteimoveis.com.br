require "rails_helper"

RSpec.describe HabitationAuditLog, type: :model do
  describe "auditoria automática do imóvel" do
    it "registra alterações feitas fora do controller administrativo" do
      habitation = create(:habitation, codigo: "AUTO-AUD-#{SecureRandom.hex(6)}", foto_classificacao: "Aceitáveis")

      expect {
        habitation.update!(foto_classificacao: "Boas")
      }.to change { HabitationAuditLog.where(habitation_id: habitation.id, action: "updated").count }.by(1)

      log = HabitationAuditLog.where(habitation_id: habitation.id, action: "updated").last
      expect(log.changed_fields).to include("foto_classificacao")
      expect(log.source).to eq("integracao")
    end
  end

  describe "#change_summaries" do
    it "formats currency and boolean values in a readable way" do
      log = build(
        :habitation_audit_log,
        changeset: {
          "valor_venda_cents" => { "before" => 900_000_00, "after" => 950_000_00 },
          "valor_vendido_terceiros_cents" => { "before" => nil, "after" => 880_000_00 },
          "motivo_suspensao" => { "before" => "", "after" => "Vendido por outra imobiliária" },
          "exibir_no_site_flag" => { "before" => false, "after" => true }
        }
      )

      summaries = log.change_summaries

      expect(summaries).to include(
        hash_including(label: "Valor de venda", before: "R$ 900.000,00", after: "R$ 950.000,00"),
        hash_including(label: "Valor vendido por terceiros", before: "vazio", after: "R$ 880.000,00"),
        hash_including(label: "Motivo de suspensão", before: "vazio", after: "Vendido por outra imobiliária"),
        hash_including(label: "Publicação no site", before: "Não", after: "Sim")
      )
    end
  end
end

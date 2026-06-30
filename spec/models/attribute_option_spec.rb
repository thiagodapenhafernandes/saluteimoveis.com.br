require "rails_helper"

RSpec.describe AttributeOption, type: :model do
  describe ".for_property_kind" do
    it "retorna a característica do tipo pedido e as sem tipo (todos), excluindo de outros tipos" do
      galpao = described_class.create!(context: "habitation", category: "feature", name: "Doca de carga ZZ", property_kinds: ["galpao"])
      residencial = described_class.create!(context: "habitation", category: "feature", name: "Closet planejado ZZ", property_kinds: ["residencial"])
      universal = described_class.create!(context: "habitation", category: "feature", name: "Detalhe universal ZZ", property_kinds: [])

      residencial_scope = described_class.for_property_kind("residencial")

      expect(residencial_scope).to include(residencial, universal)
      expect(residencial_scope).not_to include(galpao)
    end

    it "ignora tipos inválidos ao salvar (mantém só os válidos)" do
      option = described_class.create!(context: "habitation", category: "feature", name: "Caracteristica QQ", property_kinds: ["galpao", "inexistente"])

      expect(option.reload.property_kinds).to eq(["galpao"])
    end
  end
end

require "rails_helper"

RSpec.describe HabitationDuplicateChecker do
  it "ignora imóveis do mesmo grupo de captação desdobrada sem ocultar imóveis comuns" do
    group_uuid = SecureRandom.uuid
    sale = create(:habitation, intake_group_uuid: group_uuid, nome_empreendimento: "Edifício Solar", bloco: "501")
    sale.create_address!(logradouro: "Rua 1500", numero: "10", bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")

    rental = create(:habitation, intake_group_uuid: group_uuid, nome_empreendimento: "Edifício Solar", bloco: "501")
    rental.create_address!(logradouro: "Rua 1500", numero: "10", bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")

    common_duplicate = create(:habitation, nome_empreendimento: "Edifício Solar", bloco: "501")
    common_duplicate.create_address!(logradouro: "Rua 1500", numero: "10", bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")

    result = described_class.new(
      street: sale.logradouro,
      number: sale.numero,
      building: sale.nome_empreendimento,
      unit: sale.bloco,
      ignored_id: sale.id
    ).call

    expect(result.matches).to include(common_duplicate)
    expect(result.matches).not_to include(rental)
  end
end

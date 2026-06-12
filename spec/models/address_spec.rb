require "rails_helper"

RSpec.describe Address, type: :model do
  it "remove o tipo de endereço duplicado do logradouro quando o tipo foi selecionado" do
    address = described_class.new(
      tipo_endereco: "Rua",
      logradouro: "Rua 129",
      numero: "214",
      bairro: "Centro",
      cidade: "Itapema",
      uf: "SC"
    )

    address.validate

    expect(address.tipo_endereco).to eq("Rua")
    expect(address.logradouro).to eq("129")
  end

  it "reconhece abreviações do tipo de endereço" do
    address = described_class.new(
      tipo_endereco: "Av.",
      logradouro: "Av. Brasil",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    address.validate

    expect(address.tipo_endereco).to eq("Avenida")
    expect(address.logradouro).to eq("Brasil")
  end
end

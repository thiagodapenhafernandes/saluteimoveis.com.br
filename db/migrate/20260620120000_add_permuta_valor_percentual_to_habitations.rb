class AddPermutaValorPercentualToHabitations < ActiveRecord::Migration[7.1]
  def change
    # Permite informar o valor da permuta como porcentagem do valor do imóvel
    # (ex.: 20, 30), alternativa ao valor em R$ (valor_aceito_permuta_cents).
    add_column :habitations, :permuta_valor_percentual, :integer
  end
end

class AddPropertyKindsToAttributeOptions < ActiveRecord::Migration[7.1]
  def change
    # Card "Ajuste função criar características": cada característica pode ser
    # vinculada a um ou mais tipos de imóvel (residencial, comercial, galpao,
    # terreno, empreendimento). Vazio = vale para todos (compatibilidade).
    add_column :attribute_options, :property_kinds, :jsonb, default: [], null: false
  end
end

class NormalizeSalasConjuntosCategory < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE habitations
         SET categoria = 'Sala Comercial'
       WHERE categoria = 'Salas/Conjuntos'
    SQL
  end

  def down
    # Data normalization is intentionally not reversible.
  end
end

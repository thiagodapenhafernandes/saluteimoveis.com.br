class AddFrenteFundoTerrenoToHabitations < ActiveRecord::Migration[7.1]
  def up
    add_column :habitations, :frente_terreno_m, :decimal, precision: 10, scale: 2
    add_column :habitations, :fundo_terreno_m, :decimal, precision: 10, scale: 2

    # Card #13: separa o campo unico "Dimensoes Terreno" (ex.: "12x30") em
    # frente e fundo. Backfill best-effort dos registros existentes.
    rows = execute("SELECT id, dimensoes_terreno FROM habitations WHERE NULLIF(TRIM(dimensoes_terreno), '') IS NOT NULL")
    rows.each do |row|
      match = row["dimensoes_terreno"].to_s.match(/(\d+(?:[.,]\d+)?)\s*[xX×]\s*(\d+(?:[.,]\d+)?)/)
      next unless match

      frente = match[1].tr(",", ".").to_f
      fundo = match[2].tr(",", ".").to_f
      execute("UPDATE habitations SET frente_terreno_m = #{frente}, fundo_terreno_m = #{fundo} WHERE id = #{row["id"].to_i}")
    end
  end

  def down
    remove_column :habitations, :fundo_terreno_m
    remove_column :habitations, :frente_terreno_m
  end
end

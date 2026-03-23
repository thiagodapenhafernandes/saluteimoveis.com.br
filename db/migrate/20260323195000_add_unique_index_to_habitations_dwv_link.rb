class AddUniqueIndexToHabitationsDwvLink < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_habitations_on_codigo_dwv_unique_when_dwv".freeze

  def up
    remove_index :habitations, name: INDEX_NAME, algorithm: :concurrently, if_exists: true

    add_index :habitations,
              :codigo_dwv,
              unique: true,
              where: "imovel_dwv = 'Sim' AND codigo_dwv IS NOT NULL AND codigo_dwv <> ''",
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :habitations, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end

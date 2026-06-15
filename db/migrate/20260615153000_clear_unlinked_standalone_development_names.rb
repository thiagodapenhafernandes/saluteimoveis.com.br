class ClearUnlinkedStandaloneDevelopmentNames < ActiveRecord::Migration[7.1]
  STANDALONE_CATEGORIES_WITHOUT_DEVELOPMENT_NAME = %w[casa sobrado rural chacara sitio].freeze

  class MigrationHabitation < ApplicationRecord
    self.table_name = "habitations"
  end

  def up
    MigrationHabitation.reset_column_information

    MigrationHabitation
      .where.not(tipo: "Empreendimento")
      .where(codigo_empreendimento: [nil, ""])
      .where.not(nome_empreendimento: [nil, ""])
      .find_each do |habitation|
        next unless standalone_category_without_development_name?(habitation.categoria)

        habitation.update_columns(nome_empreendimento: nil)
      end
  end

  def down
    # No-op: the previous unlinked names came from Vista payload leakage and are
    # not reliably reconstructable without reintroducing incorrect data.
  end

  private

  def standalone_category_without_development_name?(category)
    STANDALONE_CATEGORIES_WITHOUT_DEVELOPMENT_NAME.include?(category.to_s.parameterize)
  end
end

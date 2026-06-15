require "set"

class BackfillCategoryMismatchedHabitationSlugs < ActiveRecord::Migration[7.1]
  class MigrationHabitation < ActiveRecord::Base
    self.table_name = "habitations"
  end

  def up
    used_slugs = MigrationHabitation.where.not(slug: [nil, ""]).pluck(:slug).to_set

    relation.find_each do |habitation|
      current_slug = habitation.slug.to_s
      code_suffix = habitation.codigo.to_s.parameterize
      category_prefix = habitation.categoria.to_s.parameterize

      next if code_suffix.blank? || category_prefix.blank?
      next unless current_slug.end_with?("-#{code_suffix}")
      next if current_slug.start_with?("#{category_prefix}-")

      base_slug = [
        category_prefix,
        habitation.cidade.to_s.parameterize.presence,
        habitation.bairro.to_s.parameterize.presence,
        code_suffix
      ].compact.join("-")
      next if base_slug.blank?

      used_slugs.delete(current_slug)
      new_slug = unique_slug_for(base_slug, used_slugs)

      habitation.update_columns(slug: new_slug)
      used_slugs.add(new_slug)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def relation
    MigrationHabitation
      .where.not(tipo: "Empreendimento")
      .where.not(slug: [nil, ""])
      .where.not(codigo: [nil, ""])
      .where.not(categoria: [nil, ""])
  end

  def unique_slug_for(base_slug, used_slugs)
    return base_slug unless used_slugs.include?(base_slug)

    sequence = 2
    loop do
      candidate = "#{base_slug}-#{sequence}"
      return candidate unless used_slugs.include?(candidate)

      sequence += 1
    end
  end
end

class SeedQuadraDePadelInfrastructureOption < ActiveRecord::Migration[7.1]
  def up
    AttributeOption.find_or_create_by!(
      context: "habitation",
      category: "infrastructure",
      name: "Quadra de padel"
    )
  end

  def down
    AttributeOption.where(
      context: "habitation",
      category: "infrastructure",
      name: "Quadra de padel"
    ).destroy_all
  end
end

class AddPhotoEnvironmentAssignmentsToHabitations < ActiveRecord::Migration[7.1]
  def change
    add_column :habitations, :photo_environment_assignments, :jsonb, null: false, default: {}
  end
end

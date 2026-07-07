class AddGoogleCalendarPhotoEventToHabitations < ActiveRecord::Migration[7.1]
  def change
    add_column :habitations, :photo_calendar_provider, :string
    add_column :habitations, :photo_calendar_event_id, :string
    add_column :habitations, :photo_calendar_error, :text
    add_column :habitations, :photo_calendar_synced_at, :datetime

    add_index :habitations, :photo_calendar_event_id
  end
end

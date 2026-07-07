module GoogleCalendar
  class PhotographyEventSyncJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(habitation_id)
      habitation = Habitation.find_by(id: habitation_id)
      return unless habitation&.photo_flow_choice == "google_calendar"
      return if habitation.photo_session_requested_at.blank?

      result = GoogleCalendar::PhotographyEventService.new(habitation).call
      now = Time.current

      if result.success?
        habitation.update_columns(
          photo_calendar_provider: "google_calendar",
          photo_calendar_event_id: result.event_id,
          photo_session_url: result.html_link.presence || habitation.photo_session_url,
          photo_calendar_synced_at: now,
          photo_calendar_error: nil,
          updated_at: now
        )
      else
        habitation.update_columns(
          photo_calendar_provider: "google_calendar",
          photo_calendar_error: result.error_message.to_s.first(1000),
          updated_at: now
        )
      end
    end
  end
end

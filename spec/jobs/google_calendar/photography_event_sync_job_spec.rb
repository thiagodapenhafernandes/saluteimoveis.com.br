require "rails_helper"

RSpec.describe GoogleCalendar::PhotographyEventSyncJob, type: :job do
  it "salva dados do evento quando a sincronizacao com Google Agenda tem sucesso" do
    habitation = create(
      :habitation,
      :broker_intake,
      codigo: "GOOGLE-SYNC-#{SecureRandom.hex(6)}",
      photo_flow_choice: "google_calendar",
      photo_session_requested_at: Time.zone.parse("2026-07-10 10:00")
    )
    result = GoogleCalendar::PhotographyEventService::Result.new(
      success: true,
      event_id: "google-event-123",
      html_link: "https://calendar.google.com/event?eid=123"
    )
    allow(GoogleCalendar::PhotographyEventService).to receive(:new).with(habitation).and_return(
      instance_double(GoogleCalendar::PhotographyEventService, call: result)
    )

    described_class.perform_now(habitation.id)

    habitation.reload
    expect(habitation.photo_calendar_provider).to eq("google_calendar")
    expect(habitation.photo_calendar_event_id).to eq("google-event-123")
    expect(habitation.photo_session_url).to eq("https://calendar.google.com/event?eid=123")
    expect(habitation.photo_calendar_synced_at).to be_present
    expect(habitation.photo_calendar_error).to be_nil
  end

  it "registra erro sem expor credenciais quando a sincronizacao falha" do
    habitation = create(
      :habitation,
      :broker_intake,
      codigo: "GOOGLE-ERR-#{SecureRandom.hex(6)}",
      photo_flow_choice: "google_calendar",
      photo_session_requested_at: Time.zone.parse("2026-07-10 10:00")
    )
    result = GoogleCalendar::PhotographyEventService::Result.new(
      success: false,
      error_message: "permission denied"
    )
    allow(GoogleCalendar::PhotographyEventService).to receive(:new).with(habitation).and_return(
      instance_double(GoogleCalendar::PhotographyEventService, call: result)
    )

    described_class.perform_now(habitation.id)

    habitation.reload
    expect(habitation.photo_calendar_provider).to eq("google_calendar")
    expect(habitation.photo_calendar_event_id).to be_nil
    expect(habitation.photo_calendar_error).to eq("permission denied")
  end
end

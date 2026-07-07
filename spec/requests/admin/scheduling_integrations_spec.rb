require "rails_helper"

RSpec.describe "Admin::SchedulingIntegrations", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  let(:google_credentials_path) { Rails.root.join("tmp/google-calendar-test.json").to_s }

  after do
    FileUtils.rm_f(google_credentials_path)
  end

  it "salva a url externa da agenda de fotos e configuracao do Google Agenda" do
    File.write(google_credentials_path, "{}")

    get admin_scheduling_integration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Agenda de fotografia")
    expect(response.body).to include("Habilitar opção Google Agenda")

    patch admin_scheduling_integration_path, params: {
      scheduling: {
        photography_schedule_url: "https://calendly.com/fotografias-saluteimoveis/30min",
        photography_google_calendar_enabled: "1",
        photography_google_calendar_id: "fotografias.saluteimoveis@gmail.com",
        photography_google_credentials_path: google_credentials_path
      }
    }

    expect(response).to redirect_to(admin_scheduling_integration_path)
    expect(Setting.get("photography_schedule_url")).to eq("https://calendly.com/fotografias-saluteimoveis/30min")
    expect(Setting.get("photography_google_calendar_enabled")).to eq("1")
    expect(Setting.get("photography_google_calendar_id")).to eq("fotografias.saluteimoveis@gmail.com")
    expect(Setting.get("photography_google_credentials_path")).to eq(google_credentials_path)
  end

  it "testa a conexao do Google Agenda com a configuracao salva" do
    allow(GoogleCalendar::PhotographyEventService).to receive(:test_connection).and_return(
      GoogleCalendar::PhotographyEventService::Result.new(success: true, event_id: "calendar-id")
    )
    post test_google_calendar_admin_scheduling_integration_path

    expect(response).to redirect_to(admin_scheduling_integration_path)
    expect(flash[:notice]).to eq("Conexão com Google Agenda validada com sucesso.")
  end

  it "bloqueia e libera dias da agenda interna" do
    post block_day_admin_scheduling_integration_path, params: {
      photography_schedule_block: { date: Date.current.next_day.to_s, reason: "Treinamento" }
    }

    block = PhotographyScheduleBlock.last
    expect(response).to redirect_to(admin_scheduling_integration_path)
    expect(block.date).to eq(Date.current.next_day)
    expect(block.reason).to eq("Treinamento")
    expect(block.created_by).to eq(admin)

    delete unblock_day_admin_scheduling_integration_path(block)

    expect(response).to redirect_to(admin_scheduling_integration_path)
    expect(PhotographyScheduleBlock.exists?(block.id)).to be(false)
  end

  it "permite que perfil fotografo veja agenda e pendencias sem gerenciar bloqueios" do
    profile = Profile.create!(
      name: "Fotógrafo teste",
      active: true,
      permissions: {
        "admin" => false,
        "agenda_fotografia" => { "view" => true, "manage" => false }
      }
    )
    photographer = create(:admin_user, profile: profile)
    habitation = create(:habitation, :broker_intake, codigo: "FOTO-#{SecureRandom.hex(6)}", titulo_anuncio: "Apartamento com fotos pendentes")

    sign_out admin
    sign_in photographer

    get admin_scheduling_integration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Apartamento com fotos pendentes")
    expect(response.body).not_to include("Bloquear dia")

    get pending_property_admin_scheduling_integration_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dados para fotografia")
    expect(response.body).to include("Apartamento com fotos pendentes")

    patch admin_scheduling_integration_path, params: {
      scheduling: { photography_schedule_url: "https://example.com/agenda" }
    }

    expect(response).to redirect_to(admin_root_path)
    expect(Setting.get("photography_schedule_url")).not_to eq("https://example.com/agenda")
  end
end

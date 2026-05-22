require "rails_helper"

RSpec.describe "Admin::DataExportAuditLogs", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin, email: "data-export-#{SecureRandom.hex(8)}@salute.test") }

  before do
    host! "localhost"
    sign_in admin
  end

  it "records habitation CSV exports" do
    create(:habitation, codigo: "EXP-#{SecureRandom.hex(6)}", titulo_anuncio: "Exportável")

    expect {
      get export_admin_habitations_path, params: { fields: %w[codigo categoria], data_format: "csv_semicolon" }
    }.to change(DataExportAuditLog, :count).by(1)

    log = DataExportAuditLog.last
    expect(response).to have_http_status(:ok)
    expect(log).to have_attributes(
      admin_user_id: admin.id,
      export_type: "csv_export",
      resource_name: "habitations",
      format: "csv_semicolon"
    )
    expect(log.record_count).to be >= 1
    expect(log.fields).to include("codigo", "categoria")
  end

  it "records proprietor CSV exports and renders audit page" do
    create(:proprietor, name: "Maria Exportação")

    expect {
      get export_admin_proprietors_path, params: { fields: %w[name phone_primary], data_format: "csv" }
    }.to change(DataExportAuditLog, :count).by(1)

    get admin_data_export_audit_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Auditoria de Exportações")
    expect(response.body).to include("Proprietários")
  end
end

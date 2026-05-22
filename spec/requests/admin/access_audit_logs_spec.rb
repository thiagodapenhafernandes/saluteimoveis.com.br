require "rails_helper"

RSpec.describe "Admin::AccessAuditLogs", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin, email: "access-audit-#{SecureRandom.hex(8)}@salute.test") }

  before do
    host! "localhost"
  end

  it "records successful and failed login attempts" do
    expect {
      post admin_user_session_path, params: {
        admin_user: { email: admin.email, password: "password123" }
      }, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" }
    }.to change(AccessAuditLog, :count).by(1)

    expect(AccessAuditLog.last).to have_attributes(event_type: "login", result: "allowed", admin_user_id: admin.id)

    delete destroy_admin_user_session_path

    expect {
      post admin_user_session_path, params: {
        admin_user: { email: admin.email, password: "senha-errada" }
      }
    }.to change(AccessAuditLog, :count).by(1)

    expect(AccessAuditLog.last).to have_attributes(event_type: "login", result: "denied", reason: "Senha inválida")
  end

  it "renders access audit page and menu entry" do
    create(:access_audit_log, admin_user: admin, result: "denied", reason: "Senha inválida")
    sign_in admin

    get admin_access_audit_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Auditoria de Acessos")
    expect(response.body).to include("Senha inválida")
    expect(response.body).to include("IPs únicos")
  end
end

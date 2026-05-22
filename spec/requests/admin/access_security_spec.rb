require "rails_helper"

RSpec.describe "Admin::AccessSecurity", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin, email: "access-security-#{SecureRandom.hex(8)}@salute.test") }

  before do
    host! "localhost"
    sign_in admin
  end

  it "renders the access security page and creates IP rules" do
    get admin_access_security_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Segurança de Acesso")

    post admin_access_control_rules_path, params: {
      access_control_rule: {
        name: "Loja Centro",
        rule_type: "allow_ip",
        scope_type: "global",
        ip_value: "10.0.0.0/24",
        enabled: "1"
      }
    }

    expect(response).to redirect_to(admin_access_security_path)
    expect(AccessControlRule.last.name).to eq("Loja Centro")
  end

  it "approves trusted devices" do
    device = create(:trusted_device, admin_user: admin)

    patch admin_trusted_device_path(device, status: "trusted")

    expect(response).to redirect_to(admin_access_security_path(anchor: "devices"))
    expect(device.reload.status).to eq("trusted")
  end
end

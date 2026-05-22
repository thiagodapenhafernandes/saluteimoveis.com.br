require "rails_helper"

RSpec.describe "Admin::WhatsappIntegrations", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "shows and saves WhatsApp settings by negotiation type" do
    get admin_whatsapp_integration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("WhatsApp")
    expect(response.body).to include("Venda e locação")

    patch admin_whatsapp_integration_path, params: {
      whatsapp: {
        default_number: "47 3311-1067",
        rules: {
          sale: { number: "47 99999-0001", capture_enabled: "1" },
          rent: { number: "47 99999-0002", capture_enabled: "0" },
          sale_rent: { number: "47 99999-0003", capture_enabled: "1" }
        }
      }
    }

    expect(response).to redirect_to(admin_whatsapp_integration_path)

    config = Whatsapp::SiteRouting.config
    expect(config["default_number"]).to eq("554733111067")
    expect(config.dig("rules", "sale", "number")).to eq("5547999990001")
    expect(config.dig("rules", "rent", "capture_enabled")).to be(false)
    expect(config.dig("rules", "sale_rent", "number")).to eq("5547999990003")
  end
end

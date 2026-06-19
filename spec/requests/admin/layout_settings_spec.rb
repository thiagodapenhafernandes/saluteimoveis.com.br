require "rails_helper"

RSpec.describe "Admin::LayoutSettings", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "abre a tela de Aparência (layout) sem erro" do
    get edit_admin_layout_setting_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configurações de Cores e Logo")
  end

  it "abre a tela de Aparência mesmo com logo PNG anexado (gera variant)" do
    setting = LayoutSetting.instance
    setting.logo.attach(
      io: StringIO.new("\x89PNG\r\n\x1A\n".b),
      filename: "logo.png",
      content_type: "image/png"
    )

    get edit_admin_layout_setting_path

    expect(response).to have_http_status(:ok)
  end
end

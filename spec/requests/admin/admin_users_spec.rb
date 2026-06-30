require "rails_helper"

RSpec.describe "Admin::AdminUsers", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "lista apenas usuários ativos por padrão e permite ver todos" do
    ativo = create(:admin_user, active: true, name: "Usuário Ativo #{SecureRandom.hex(4)}")
    inativo = create(:admin_user, active: false, name: "Usuário Inativo #{SecureRandom.hex(4)}")

    get admin_admin_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ativo.name)
    expect(response.body).not_to include(inativo.name)

    get admin_admin_users_path(status: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ativo.name)
    expect(response.body).to include(inativo.name)
  end
end

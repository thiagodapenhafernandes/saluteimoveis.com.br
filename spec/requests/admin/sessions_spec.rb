require "rails_helper"

RSpec.describe "Admin::Sessions", type: :request do
  before { host! "localhost" }

  it "exibe o botão de mostrar/ocultar senha na tela de login" do
    get new_admin_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="password-visibility"')
    expect(response.body).to include('data-password-visibility-target="input"')
    expect(response.body).to include('data-action="password-visibility#toggle"')
    expect(response.body).to include("bi-eye")
  end
end

require "rails_helper"

RSpec.describe "Admin::Proprietors busca", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "encontra proprietário existente por telefone e devolve dados para pré-preencher" do
    proprietor = create(:proprietor, name: "Maria das Dores", mobile_phone: "(47) 98888-1234",
                        email: "maria@x.com", city: "Itajaí", cpf_cnpj: "111.222.333-44")

    get search_admin_proprietors_path(phone: "47988881234"), headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["found"]).to be(true)
    expect(body.dig("proprietor", "name")).to eq("Maria das Dores")
    expect(body.dig("proprietor", "city")).to eq("Itajaí")
    expect(body.dig("proprietor", "edit_url")).to eq(edit_admin_proprietor_path(proprietor))
  end

  it "retorna found:false quando não há proprietário com aquele telefone" do
    get search_admin_proprietors_path(phone: "47900000000"), headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["found"]).to be(false)
  end

  it "também busca por CPF/CNPJ" do
    create(:proprietor, name: "João", cpf_cnpj: "555.666.777-88", city: "Camboriú")

    get search_admin_proprietors_path(cpf_cnpj: "55566677788"), headers: { "Accept" => "application/json" }

    expect(JSON.parse(response.body).dig("proprietor", "name")).to eq("João")
  end
end

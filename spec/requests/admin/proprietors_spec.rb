require "rails_helper"

RSpec.describe "Admin::Proprietors", type: :request do
  include Devise::Test::IntegrationHelpers

  before { host! "localhost" }

  it "permite gerente com visualização acessar proprietários sem ações de gestão" do
    profile = Profile.create!(
      name: "Gerente proprietários #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Gerente").merge(
        "proprietarios" => { "view" => true, "manage" => false }
      )
    )
    manager = create(:admin_user, profile: profile)
    proprietor = create(
      :proprietor,
      name: "Proprietário Visível",
      email: "visivel@example.com",
      phone_primary: "(47) 3333-0000",
      mobile_phone: "(47) 99999-0000",
      business_phone: "(47) 3222-0000",
      residential_phone: "(47) 3111-0000"
    )

    sign_in manager

    get admin_proprietors_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proprietário Visível")
    expect(response.body).to include("visivel@example.com")
    expect(response.body).to include("(47) 3333-0000")
    expect(response.body).to include("(47) 99999-0000")
    expect(response.body).to include("(47) 3222-0000")
    expect(response.body).to include("(47) 3111-0000")
    expect(response.body).not_to include("Novo Proprietário")
    expect(response.body).not_to include(new_admin_proprietor_path)
    expect(response.body).not_to include(edit_admin_proprietor_path(proprietor))
    expect(response.body).not_to include("proprietorsExportModal")
  end

  it "bloqueia ações de gestão quando o perfil só tem visualização de proprietários" do
    profile = Profile.create!(
      name: "Gerente proprietários bloqueio #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Gerente").merge(
        "proprietarios" => { "view" => true, "manage" => false }
      )
    )
    manager = create(:admin_user, profile: profile)
    proprietor = create(:proprietor)

    sign_in manager

    get new_admin_proprietor_path
    expect(response).to redirect_to(admin_root_path)

    get edit_admin_proprietor_path(proprietor)
    expect(response).to redirect_to(admin_root_path)

    get export_admin_proprietors_path, params: { fields: %w[name], data_format: "csv" }
    expect(response).to redirect_to(admin_root_path)
  end

  it "bloqueia listagem quando o perfil não tem visualização de proprietários" do
    profile = Profile.create!(
      name: "Sem proprietários #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Gerente").merge(
        "proprietarios" => { "view" => false, "manage" => false }
      )
    )
    manager = create(:admin_user, profile: profile)

    sign_in manager

    get admin_proprietors_path

    expect(response).to redirect_to(admin_root_path)
  end

  it "cria proprietário rápido e retorna payload para selecionar no cadastro do imóvel" do
    admin = create(:admin_user, :admin)
    sign_in admin

    expect {
      post quick_create_admin_proprietors_path,
           params: {
             proprietor: {
               name: "Proprietário Modal",
               phone_primary: "(47) 99999-1111",
               email: "modal@example.com"
             }
           },
           headers: { "ACCEPT" => "application/json" }
    }.to change(Proprietor, :count).by(1)

    expect(response).to have_http_status(:created)
    payload = JSON.parse(response.body)
    proprietor = Proprietor.last
    expect(payload).to include("id" => proprietor.id, "name" => proprietor.select_label)
    expect(proprietor).to have_attributes(
      role: "owner",
      phone_primary: "(47) 99999-1111",
      email: "modal@example.com"
    )
  end

  it "permite criação rápida para perfil Administrativo" do
    profile = Profile.find_or_create_by!(name: "Administrativo") do |record|
      record.permissions = Profile.default_permissions_for("Administrativo")
    end
    administrative = create(:admin_user, profile: profile)
    sign_in administrative

    post quick_create_admin_proprietors_path,
         params: { proprietor: { name: "Proprietário Administrativo" } },
         headers: { "ACCEPT" => "application/json" }

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)["name"]).to eq(Proprietor.last.select_label)
  end

  it "reaproveita proprietário existente por telefone no cadastro rápido" do
    admin = create(:admin_user, :admin)
    existing = create(:proprietor, name: "Proprietário Existente", mobile_phone: "47999991111")
    sign_in admin

    expect {
      post quick_create_admin_proprietors_path,
           params: {
             proprietor: {
               phone_primary: "(47) 99999-1111"
             }
           },
           headers: { "ACCEPT" => "application/json" }
    }.not_to change(Proprietor, :count)

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)).to include("id" => existing.id, "name" => existing.reload.select_label)
  end
end

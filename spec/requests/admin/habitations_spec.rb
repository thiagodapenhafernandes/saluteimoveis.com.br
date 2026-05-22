require "rails_helper"

RSpec.describe "Admin::Habitations", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "lista captações finalizadas no menu de imóveis e oculta rascunhos" do
    draft = create(:habitation, :broker_intake, admin_user: admin, codigo: "DRAFT-#{SecureRandom.hex(6)}", titulo_anuncio: "Captação em rascunho")
    submitted = create(:habitation, :broker_intake, admin_user: admin, codigo: "REV-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review", titulo_anuncio: "Captação finalizada")
    approved = create(:habitation, :broker_intake, admin_user: admin, codigo: "APP-#{SecureRandom.hex(6)}", intake_status: "admin_approved", titulo_anuncio: "Captação aprovada")

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pendente de revisão")
    expect(response.body).to include(submitted.titulo_anuncio)
    expect(response.body).to include(approved.titulo_anuncio)
    expect(response.body).not_to include(draft.titulo_anuncio)

    get admin_habitations_path(intake_review: "pending", ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(submitted.titulo_anuncio)
    expect(response.body).not_to include(approved.titulo_anuncio)
    expect(response.body).not_to include(draft.titulo_anuncio)
  end

  it "salva o imóvel completo e libera a captação para o corretor publicar" do
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "REL-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    intake.autorizacoes_venda.attach(
      io: StringIO.new("autorizacao"),
      filename: "autorizacao.txt",
      content_type: "text/plain"
    )

    patch admin_habitation_path(intake), params: {
      release_to_broker_after_save: "1",
      habitation: {
        titulo_anuncio: "Apartamento completo pelo administrativo",
        exibir_no_site_flag: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      titulo_anuncio: "Apartamento completo pelo administrativo",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: admin.id
    )
    expect(intake.admin_reviewed_at).to be_present
  end

  it "exibe e atualiza o status separado da captação no cadastro completo" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "REV-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review"
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    get edit_admin_habitation_path(intake)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Status da captação")
    expect(response.body).to include("Fluxo separado do status comercial.")

    patch admin_habitation_path(intake), params: {
      habitation: {
        intake_status: "returned_to_broker",
        status: "Venda"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "returned_to_broker",
      status: "Venda",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: admin.id
    )
    expect(intake.admin_reviewed_at).to be_present
  end

  it "exibe região foco como decisão sim ou não no cadastro completo" do
    habitation = create(:habitation, codigo: "FOCO-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Região foco?")
    expect(response.body).to include(">Sim<")
    expect(response.body).to include(">Não<")
    expect(response.body).not_to include(">Centro<")
  end

  it "bloqueia cadastro de imóvel com mesma rua, número, prédio e unidade" do
    existing = create(:habitation, codigo: "DUP-#{SecureRandom.hex(6)}", nome_empreendimento: "Edifício Aurora", bloco: "1203")
    existing.create_address!(
      logradouro: "Rua 1500",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    expect {
      post admin_habitations_path, params: {
        habitation: {
          categoria: "Apartamento",
          status: "Venda",
          tipo: "Unitário",
          nome_empreendimento: "Edificio Aurora",
          bloco: "Apto 1203",
          address_attributes: {
            logradouro: "Rua 1500",
            numero: "100",
            bairro: "Centro",
            cidade: "Balneário Camboriú",
            uf: "SC"
          }
        }
      }
    }.not_to change(Habitation, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Já existe imóvel cadastrado")
  end

  it "retorna duplicidade em tempo real por endereço completo" do
    existing = create(:habitation, codigo: "CHK-#{SecureRandom.hex(6)}", nome_empreendimento: "Edifício Aurora", bloco: "1203")
    existing.create_address!(
      logradouro: "Rua 1500",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    get check_admin_habitation_duplicate_path, params: {
      street: "rua 1500",
      number: "100",
      building: "Edificio Aurora",
      unit: "apto 1203"
    }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload.fetch("complete")).to eq(true)
    expect(payload.fetch("duplicate")).to eq(true)
    expect(payload.fetch("matches").first.fetch("codigo")).to eq(existing.codigo)
  end
end

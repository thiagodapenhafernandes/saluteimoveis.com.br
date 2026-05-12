require "rails_helper"

RSpec.describe "Admin::HabitationIntakes", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "cria uma captação como imóvel oculto" do
    expect {
      get new_admin_captacao_path
    }.to change { Habitation.broker_intakes.count }.by(1)

    intake = Habitation.broker_intakes.order(:created_at).last
    expect(response).to redirect_to(edit_admin_captacao_path(intake))
    expect(intake).to have_attributes(
      intake_status: "draft",
      exibir_no_site_flag: false,
      admin_user_id: admin.id
    )
  end

  it "bloqueia envio para revisão quando faltam campos obrigatórios" do
    intake = create(:habitation, :broker_intake, admin_user: admin, proprietario: nil)

    post submit_for_review_admin_captacao_path(intake)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(intake.reload.intake_status).to eq("draft")
  end

  it "renderiza a etapa de fotos com lista ordenável e agendamento reativo" do
    Setting.set("photography_schedule_url", "https://calendly.com/fotografias-saluteimoveis/30min")
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "fotos")

    get edit_admin_captacao_path(intake, step: "fotos")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-controller=\"captacao-photos\"")
    expect(response.body).to include("Fotos selecionadas agora")
    expect(response.body).to include("Abrir agenda de fotos")
    expect(response.body).to include("https://calendly.com/fotografias-saluteimoveis/30min")
  end

  it "bloqueia avanço no próprio step e marca campos obrigatórios" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "endereco")

    patch admin_captacao_path(intake), params: {
      current_step: "endereco",
      direction: "forward",
      habitation: {
        zip_code: "",
        street: "",
        street_number: "",
        neighborhood: "",
        city: "",
        state: "",
        edificio_nome: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Informe o CEP.")
    expect(response.body).to include("Informe o nome do condomínio/empreendimento.")
    expect(response.body).to include("is-invalid")
    expect(intake.reload.intake_step).to eq("endereco")
  end

  it "marca quantidades obrigatórias zeradas no step de características" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "caracteristicas")

    patch admin_captacao_path(intake), params: {
      current_step: "caracteristicas",
      direction: "forward",
      habitation: {
        area_total: "0",
        area_privativa: "22",
        dormitorios: "0",
        banheiros: "0",
        caracteristicas_imovel: [],
        caracteristicas_predio: []
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Informe a área total do imóvel.")
    expect(response.body).to include("Informe a quantidade de dormitórios.")
    expect(response.body).to include("Informe a quantidade de banheiros.")
    expect(response.body).to include("is-invalid")
    expect(intake.reload.intake_step).to eq("caracteristicas")
  end

  it "carrega características do catálogo do cadastro completo na captação" do
    AttributeOption.create!(context: "habitation", category: "feature", name: "Vista panorâmica")
    AttributeOption.create!(context: "habitation", category: "infrastructure", name: "Espaço gourmet")
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "caracteristicas")

    get edit_admin_captacao_path(intake, step: "caracteristicas")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vista panorâmica")
    expect(response.body).to include("Espaço gourmet")
  end

  it "aceita valores monetários formatados na negociação" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "negociacao")

    patch admin_captacao_path(intake), params: {
      current_step: "negociacao",
      direction: "forward",
      habitation: {
        valor_venda: "1.234.567,89",
        valor_condominio: "1.000,00",
        valor_iptu: "500,00",
        saldo_devedor: "120.000,00",
        aceita_permuta_answer: "nao",
        aceita_parcelamento_flag: "false"
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "visitas"))
    expect(intake.reload.valor_venda_cents).to eq(123_456_789)
    expect(intake.valor_condominio_cents).to eq(100_000)
    expect(intake.valor_iptu_cents).to eq(50_000)
    expect(intake.saldo_devedor_cents).to eq(12_000_000)
  end

  it "mantém rascunho incompleto sem valor, mas bloqueia envio para revisão" do
    intake = create(:habitation, :broker_intake, admin_user: admin, valor_venda_cents: nil)

    post submit_for_review_admin_captacao_path(intake)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Informe um valor de venda válido")
    expect(intake.reload.intake_status).to eq("draft")
  end

  it "bloqueia valor simbólico na negociação" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "negociacao")

    patch admin_captacao_path(intake), params: {
      current_step: "negociacao",
      direction: "forward",
      habitation: {
        valor_venda: "1,00",
        valor_condominio: "1.000,00",
        valor_iptu: "500,00",
        aceita_permuta_answer: "nao",
        aceita_parcelamento_flag: "false"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("mínimo R$ 10.000")
    expect(response.body).to include("is-invalid")
    expect(intake.reload.intake_step).to eq("negociacao")
  end

  it "bloqueia avanço da captação quando endereço completo já existe" do
    existing = create(:habitation, nome_empreendimento: "Residencial Atlântico", bloco: "301")
    existing.create_address!(
      logradouro: "Rua 3000",
      numero: "50",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "endereco")

    patch admin_captacao_path(intake), params: {
      current_step: "endereco",
      direction: "forward",
      habitation: {
        street: "Rua 3000",
        street_number: "50",
        neighborhood: "Centro",
        city: "Balneário Camboriú",
        state: "SC",
        edificio_nome: "Residencial Atlantico",
        unidade_numero: "ap 301"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Já existe imóvel cadastrado")
    expect(intake.reload.intake_step).to eq("endereco")
  end

  it "envia, aprova e libera para o site quando a ficha está completa" do
    intake = create(:habitation, :broker_intake, admin_user: admin)
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

    post submit_for_review_admin_captacao_path(intake)
    expect(response).to redirect_to(admin_captacao_path(intake))
    expect(intake.reload.intake_status).to eq("submitted_for_admin_review")

    post approve_admin_captacao_path(intake), params: { admin_review_notes: "Ok" }
    expect(response).to redirect_to(admin_captacao_path(intake))
    expect(intake.reload.intake_status).to eq("admin_approved")

    post release_to_site_admin_captacao_path(intake)
    expect(response).to redirect_to(admin_captacao_path(intake))
    expect(intake.reload).to have_attributes(intake_status: "published", exibir_no_site_flag: true)
  end
end

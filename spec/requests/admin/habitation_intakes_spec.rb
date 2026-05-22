require "rails_helper"

RSpec.describe "Admin::HabitationIntakes", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  it "abre nova captação sem criar rascunho automaticamente" do
    expect {
      get new_admin_captacao_path
    }.not_to change { Habitation.broker_intakes.count }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sem rascunho criado")
    expect(response.body).to include("Iniciar captação")
  end

  it "cria rascunho somente quando o corretor inicia a captação" do
    expect {
      post admin_captacoes_path, params: {
        habitation: {
          property_kind: "terreno",
          modalidade: "locacao_anual"
        }
      }
    }.to change { Habitation.broker_intakes.count }.by(1)

    intake = Habitation.broker_intakes.order(:created_at).last
    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "proprietario"))
    expect(intake).to have_attributes(
      intake_status: "draft",
      intake_step: "proprietario",
      exibir_no_site_flag: false,
      admin_user_id: admin.id,
      categoria: "Terreno",
      status: "Aluguel",
      intake_modalidade: "locacao_anual"
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
    expect(response.body).to include("Vista Panorâmica")

    get edit_admin_captacao_path(intake, step: "infraestrutura")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Espaço gourmet")
  end

  it "separa características do imóvel e do edifício em etapas diferentes" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "caracteristicas")

    patch admin_captacao_path(intake), params: {
      current_step: "caracteristicas",
      direction: "forward",
      habitation: {
        area_total: "120",
        dormitorios: "2",
        banheiros: "2",
        caracteristicas_imovel: ["Sacada"]
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "infraestrutura"))
  end

  it "limpa opções técnicas e duplicadas na ficha de captação" do
    AttributeOption.create!(context: "habitation", category: "feature", name: "ar_condicionado")
    AttributeOption.create!(context: "habitation", category: "feature", name: "Ar Condicionado")
    AttributeOption.create!(context: "habitation", category: "feature", name: "banheiro_social")
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "caracteristicas")

    get edit_admin_captacao_path(intake, step: "caracteristicas")

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('value="Ar-condicionado"').size).to eq(1)
    expect(response.body).to include("Banheiro Social")
    expect(response.body).not_to include("ar_condicionado")
    expect(response.body).not_to include("banheiro_social")
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

  it "mantém venda e locação como modalidade única durante o rascunho" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "negociacao", intake_modalidade: "ambos")

    get edit_admin_captacao_path(intake, step: "negociacao")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Valor de venda")
    expect(response.body).to include("Valor de locação")
  end

  it "mantém rascunho incompleto sem valor, mas bloqueia envio para revisão" do
    intake = create(:habitation, :broker_intake, admin_user: admin, valor_venda_cents: nil)

    post submit_for_review_admin_captacao_path(intake)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Informe um valor de venda válido")
    expect(intake.reload.intake_status).to eq("draft")
  end

  it "anexa autorização enviada no passo de fotos antes de validar avanço" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "fotos", photo_flow_choice: "upload")
    intake.photos.attach(
      io: StringIO.new("foto"),
      filename: "foto.jpg",
      content_type: "image/jpeg"
    )
    authorization = Rack::Test::UploadedFile.new(
      StringIO.new("autorizacao"),
      "image/png",
      original_filename: "autorizacao.png"
    )

    patch admin_captacao_path(intake), params: {
      current_step: "fotos",
      direction: "forward",
      habitation: {
        photos: [""],
        autorizacoes_venda: [authorization]
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "review"))
    expect(intake.reload.autorizacoes_venda).to be_attached
    expect(intake.photos).to be_attached
  end

  it "não remove anexos existentes quando o navegador envia campos de arquivo vazios" do
    intake = create(:habitation, :broker_intake, admin_user: admin, intake_step: "fotos", photo_flow_choice: "upload")
    intake.photos.attach(io: StringIO.new("foto"), filename: "foto.jpg", content_type: "image/jpeg")
    intake.autorizacoes_venda.attach(io: StringIO.new("autorizacao"), filename: "autorizacao.png", content_type: "image/png")

    patch admin_captacao_path(intake), params: {
      current_step: "fotos",
      direction: "forward",
      habitation: {
        photos: [""],
        autorizacoes_venda: [""]
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "review"))
    expect(intake.reload.photos).to be_attached
    expect(intake.autorizacoes_venda).to be_attached
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

  it "bloqueia campos sensíveis para corretor após publicação no site" do
    broker_profile = Profile.create!(
      name: "Corretor teste",
      active: true,
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: broker,
      intake_status: "published",
      intake_step: "negociacao",
      exibir_no_site_flag: true,
      nome_empreendimento: "Residencial Original",
      titulo_anuncio: "Título original",
      descricao_web: "Descrição original",
      proprietario: "Proprietário original",
      proprietario_celular: "(47) 99999-0000",
      valor_venda_cents: 900_000_00
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Original",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    sign_out admin
    sign_in broker

    patch admin_captacao_path(intake), params: {
      current_step: "negociacao",
      habitation: {
        edificio_nome: "Residencial Alterado",
        titulo_anuncio: "Título alterado",
        descricao_web: "Descrição alterada",
        proprietario_nome: "Proprietário alterado",
        proprietario_telefone: "(47) 98888-1111",
        zip_code: "88331-000",
        street: "Rua Alterada",
        street_number: "200",
        neighborhood: "Barra Sul",
        city: "Itajaí",
        state: "SC",
        valor_venda: "1200000"
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "visitas"))
    intake.reload
    expect(intake).to have_attributes(
      nome_empreendimento: "Residencial Original",
      titulo_anuncio: "Título original",
      proprietario: "Proprietário original",
      proprietario_celular: "(47) 99999-0000",
      valor_venda_cents: 120_000_000
    )
    expect(intake.descricao_web.to_plain_text).to eq("Descrição original")
    expect(intake.address).to have_attributes(
      logradouro: "Rua Original",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      cep: "88330-000"
    )
  end

  it "permite que administrativo altere campos sensíveis após publicação" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      intake_status: "published",
      intake_step: "endereco",
      exibir_no_site_flag: true,
      nome_empreendimento: "Residencial Original",
      titulo_anuncio: "Título original",
      descricao_web: "Descrição original",
      proprietario: "Proprietário original"
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Original",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_captacao_path(intake), params: {
      current_step: "endereco",
      habitation: {
        edificio_nome: "Residencial Alterado",
        zip_code: "88331-000",
        street: "Rua Alterada",
        street_number: "200",
        neighborhood: "Barra Sul",
        city: "Itajaí",
        state: "SC"
      }
    }

    expect(response).to redirect_to(edit_admin_captacao_path(intake, step: "caracteristicas"))
    intake.reload
    expect(intake.nome_empreendimento).to eq("Residencial Alterado")
    expect(intake.address).to have_attributes(
      logradouro: "Rua Alterada",
      numero: "200",
      bairro: "Barra Sul",
      cidade: "Itajaí",
      cep: "88331-000"
    )
  end

  it "desdobra venda e locação em dois cadastros ao enviar para revisão" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      intake_modalidade: "ambos",
      valor_venda_cents: 1_200_000_00,
      valor_locacao_cents: 8_500_00,
      salute_rental_management_answer: "sim"
    )
    intake.create_address!(
      cep: "88330-100",
      logradouro: "Rua Dupla",
      numero: "200",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    intake.autorizacoes_venda.attach(
      io: StringIO.new("autorizacao"),
      filename: "autorizacao.txt",
      content_type: "text/plain"
    )

    expect {
      post submit_for_review_admin_captacao_path(intake)
    }.to change { Habitation.broker_intakes.count }.by(1)

    expect(response).to redirect_to(admin_captacao_path(intake))
    sale = intake.reload
    rental = Habitation.where(intake_group_uuid: sale.intake_group_uuid).where.not(id: sale.id).sole
    expect(sale).to have_attributes(
      intake_status: "submitted_for_admin_review",
      intake_modalidade: "venda",
      status: "Venda",
      valor_venda_cents: 1_200_000_00,
      valor_locacao_cents: 0
    )
    expect(rental).to have_attributes(
      intake_status: "submitted_for_admin_review",
      intake_modalidade: "locacao_anual",
      status: "Aluguel",
      valor_venda_cents: 0,
      valor_locacao_cents: 8_500_00,
      intake_group_uuid: sale.intake_group_uuid
    )
    expect(rental.address.logradouro).to eq("Rua Dupla")
    expect(rental.autorizacoes_venda).to be_attached
  end
end

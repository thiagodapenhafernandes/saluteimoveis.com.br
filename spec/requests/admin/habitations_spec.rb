require "rails_helper"
require "tempfile"

RSpec.describe "Admin::Habitations", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

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

  it "filtra somente imóveis do DWV na listagem" do
    dwv_property = create(
      :habitation,
      codigo: "DWV-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel vindo do DWV",
      imovel_dwv: "Sim"
    )
    vista_property = create(
      :habitation,
      codigo: "VISTA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel vindo da Vista",
      imovel_dwv: "Nao"
    )

    get admin_habitations_path(somente_dwv: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Somente imóveis do DWV")
    expect(response.body).to include(dwv_property.titulo_anuncio)
    expect(response.body).not_to include(vista_property.titulo_anuncio)
  end

  it "não inclui imóveis apenas vinculados como corretor secundário em Meus imóveis" do
    broker_profile = Profile.create!(
      name: "Corretor ownership #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    luciana = create(:admin_user, profile: broker_profile, name: "Luciana Indalécio")
    patricia = create(:admin_user, profile: broker_profile, name: "Patrícia Paula")
    own_property = create(:habitation, admin_user: luciana, codigo: "OWN-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel da Luciana")
    secondary_property = create(:habitation, admin_user: patricia, codigo: "SEC-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel da Patrícia")
    secondary_property.broker_assignments.create!(admin_user: luciana, role: "captador")

    sign_in luciana
    get admin_habitations_path(ownership: "mine")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_property.titulo_anuncio)
    expect(response.body).not_to include(secondary_property.titulo_anuncio)
  end

  it "ordena imóveis novos no topo quando a data de cadastro CRM está vazia" do
    old_property = create(:habitation, codigo: "OLD-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel antigo", data_cadastro_crm: 2.days.ago)
    new_property = create(:habitation, codigo: "NEW-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel novo")
    new_property.update_column(:data_cadastro_crm, nil)

    get admin_habitations_path(sort: "data_cadastro_crm", direction: "desc")

    expect(response).to have_http_status(:ok)
    expect(response.body.index(new_property.titulo_anuncio)).to be < response.body.index(old_property.titulo_anuncio)
  end

  it "filtra por rua considerando endereço estruturado e legado" do
    structured = create(:habitation, codigo: "RUA-EST-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel Rua Estruturada")
    structured.create_address!(
      tipo_endereco: "Rua",
      logradouro: "Central Norte",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    legacy = create(
      :habitation,
      codigo: "RUA-LEG-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel Rua Legada",
      endereco: "Avenida Atlântica, 500"
    )

    get admin_habitations_path(logradouro: "Central Norte")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(structured.titulo_anuncio)
    expect(response.body).not_to include(legacy.titulo_anuncio)

    get admin_habitations_path(logradouro: "Atlântica")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(legacy.titulo_anuncio)
    expect(response.body).not_to include(structured.titulo_anuncio)
  end

  it "inclui nome de prédio sem cadastro de empreendimento no filtro de imóveis" do
    standalone_unit = create(
      :habitation,
      codigo: "PREDIO-UNIT-#{SecureRandom.hex(6)}",
      tipo: "Unitário",
      codigo_empreendimento: nil,
      nome_empreendimento: "Residencial Sem Cadastro",
      titulo_anuncio: "Unidade com prédio direto"
    )
    other_property = create(
      :habitation,
      codigo: "PREDIO-OTHER-#{SecureRandom.hex(6)}",
      tipo: "Unitário",
      codigo_empreendimento: nil,
      nome_empreendimento: "Outro Prédio",
      titulo_anuncio: "Outro imóvel"
    )

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Residencial Sem Cadastro")

    get admin_habitations_path(empreendimento_codigo: "Residencial Sem Cadastro")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(standalone_unit.titulo_anuncio)
    expect(response.body).not_to include(other_property.titulo_anuncio)
  end

  it "preserva filtros da listagem ao editar e salvar saindo" do
    habitation = create(:habitation, codigo: "RET-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel com retorno")
    habitation.create_address!(
      logradouro: "Rua Retorno",
      numero: "123",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    return_path = admin_habitations_path(q: habitation.codigo, status: habitation.status)

    get return_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(CGI.escape(return_path))

    get edit_admin_habitation_path(habitation, return_to: return_path)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ERB::Util.html_escape(return_path))

    patch admin_habitation_path(habitation), params: {
      return_to: return_path,
      save_navigation: "exit",
      habitation: {
        titulo_anuncio: "Imóvel com retorno atualizado",
        address_attributes: {
          id: habitation.address.id,
          logradouro: "Rua Retorno",
          numero: "123",
          bairro: "Centro",
          cidade: "Balneário Camboriú",
          uf: "SC"
        }
      }
    }

    expect(response).to redirect_to(return_path)
  end

  it "não exibe Netimóveis 2 e Loft na área de portais" do
    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Publicar Netimoveis 2")
    expect(response.body).not_to include("Publicar Loft")
    expect(response.body).not_to include('value="netimoveis_2"')
    expect(response.body).not_to include('value="loft"')
  end

  it "remove Praia Brava Balneário Camboriú da lista de bairros comerciais" do
    create(:habitation, codigo: "BAIRRO-#{SecureRandom.hex(6)}", bairro_comercial: "Praia Brava Balneário Camboriú")

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Praia Brava Balneário Camboriú")
  end

  it "marca cards inativos com classe visual cinza" do
    inactive = create(:habitation, :unavailable, codigo: "INATIVO-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel inativo")

    get admin_habitations_path(q: inactive.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("property-card--inactive")
  end

  it "renderiza o catálogo em layout master-detail com menu lateral por drawer" do
    create(:habitation, codigo: "LAYOUT-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel para layout master detail")

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('body class="admin-layout admin-drawer-catalog-layout"')
    expect(response.body).to include('class="habitations-master-detail-layout"')
    expect(response.body).to include('class="habitations-detail-pane"')
    expect(response.body).to include('class="habitations-master-pane"')
    expect(response.body).to include('data-bs-target="#adminSidebarOffcanvas"')
  end

  it "abre os relatórios de impressão do menu principal" do
    create(:habitation, codigo: "PRINT-#{SecureRandom.hex(6)}", categoria: "Apartamento", titulo_anuncio: "Imóvel residencial para impressão")
    create(:habitation, codigo: "PRINT-#{SecureRandom.hex(6)}", categoria: "Sala Comercial", titulo_anuncio: "Imóvel comercial para impressão")
    create(:habitation, codigo: "PRINT-#{SecureRandom.hex(6)}", categoria: "Terreno", titulo_anuncio: "Terreno para impressão")

    %w[
      photos_sheet
      client_sheet_commercial
      client_sheet_residential
      client_sheet_land
      vitrine_sheet
    ].each do |report_type|
      get print_admin_habitations_path(report_type: report_type, full_print: "1")

      expect(response).to have_http_status(:ok), "esperava abrir o relatório #{report_type}"
      expect(response.body).to include(Admin::HabitationsController::REPORT_TYPES.fetch(report_type).upcase)
    end
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

    warn response.body.scan(/(?:alert[^>]*>|invalid-feedback[^>]*>|Já existe|erro|não|falhou|inválid|propriet)[^<]{0,220}/i).uniq.first(30).join("\n")

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      titulo_anuncio: "Apartamento completo pelo administrativo",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: admin.id
    )
    expect(intake.admin_reviewed_at).to be_present
  end

  it "salva captação revisada internamente sem exibir no site" do
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "INT-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Interna",
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

    get edit_admin_habitation_path(intake)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Devolver ao corretor publicar")
    expect(response.body).to include("Salvar Interno")
    expect(response.body).to include("Salvar e sair")

    patch admin_habitation_path(intake), params: {
      save_internal_after_save: "1",
      habitation: {
        titulo_anuncio: "Apartamento salvo internamente",
        exibir_no_site_flag: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      titulo_anuncio: "Apartamento salvo internamente",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: admin.id
    )
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

  it "exibe telefone do proprietário vinculado quando o imóvel não tem telefone legado" do
    proprietor = create(
      :proprietor,
      name: "Jeanine",
      phone_primary: "47 98868.0402",
      mobile_phone: nil,
      business_phone: nil,
      residential_phone: nil
    )
    habitation = create(
      :habitation,
      proprietor: proprietor,
      proprietario: "Jeanine",
      proprietario_celular: nil,
      proprietario_telefone_comercial: nil,
      proprietario_telefone_residencial: nil
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jeanine")
    expect(response.body).to include("47 98868.0402")
  end

  it "mantém classificação de fotos visível para o administrativo" do
    habitation = create(:habitation, codigo: "FOTO-ADM-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Classificação das Fotos:")
  end

  it "não remove fotos existentes quando o formulário envia upload vazio" do
    habitation = create(:habitation, codigo: "FOTO-KEEP-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "101",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    habitation.photos.attach(
      io: StringIO.new("foto existente"),
      filename: "existente.jpg",
      content_type: "image/jpeg"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título sem trocar foto",
        photos: [""]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.titulo_anuncio).to eq("Título sem trocar foto")
    expect(habitation.photos.attachments.size).to eq(1)
    expect(habitation.photos.attachments.first.filename.to_s).to eq("existente.jpg")
  end

  it "remove fotos anexadas selecionadas ao salvar o imóvel" do
    habitation = create(:habitation, codigo: "FOTO-DEL-#{SecureRandom.hex(6)}")
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "102",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    habitation.photos.attach(
      io: StringIO.new("foto um"),
      filename: "foto-um.jpg",
      content_type: "image/jpeg"
    )
    habitation.photos.attach(
      io: StringIO.new("foto dois"),
      filename: "foto-dois.jpg",
      content_type: "image/jpeg"
    )
    attachments = habitation.photos.attachments.order(:id).to_a
    habitation.update!(photo_ids_order: attachments.map(&:id))

    perform_enqueued_jobs do
      patch admin_habitation_path(habitation), params: {
        habitation: {
          titulo_anuncio: "Título mantendo uma foto",
          ordered_photo_ids: attachments.map(&:id).join(","),
          remove_photo_ids: attachments.first.id.to_s
        }
      }
    end

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.photos.attachments.map(&:id)).to contain_exactly(attachments.second.id)
    expect(habitation.photo_ids_order).to eq([attachments.second.id])
    expect(HabitationAuditLog.where(habitation_id: habitation.id, action: "attachments_changed").last.changed_fields).to include("photos_attachments")
  end

  it "remove fotos da API selecionadas ao salvar o imóvel" do
    habitation = create(
      :habitation,
      codigo: "FOTO-API-#{SecureRandom.hex(6)}",
      pictures: [
        { "url" => "https://example.com/um.jpg" },
        { "url" => "https://example.com/dois.jpg" },
        { "url" => "https://example.com/tres.jpg" }
      ]
    )
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "103",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título sem a segunda foto API",
        remove_picture_indices: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.pictures.map { |picture| picture["url"] }).to eq([
      "https://example.com/um.jpg",
      "https://example.com/tres.jpg"
    ])
  end

  it "exibe modal para escolher como concluir o salvamento do cadastro" do
    habitation = create(:habitation, codigo: "SAVE-MODAL-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Como deseja salvar?")
    expect(response.body).to include("Salvar e permanecer")
    expect(response.body).to include("Salvar e sair")
    expect(response.body).to include("Cancelar")
    expect(response.body).to include("data-habitation-save-options-form")
    expect(response.body).to include("data-habitation-save-options-action")
  end

  it "permanece na ficha de cadastro quando solicitado no salvamento" do
    habitation = create(:habitation, codigo: "SAVE-STAY-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Salvamento",
      numero: "123",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      habitation: {
        titulo_anuncio: "Título salvo na ficha"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation))
    follow_redirect!
    expect(response.body).to include("Imóvel atualizado com sucesso. Você permaneceu na ficha de cadastro.")
    expect(habitation.reload.titulo_anuncio).to eq("Título salvo na ficha")
  end

  it "atualiza o seletor Exibir no site no cadastro do imóvel" do
    habitation = create(:habitation, codigo: "SITE-FLAG-#{SecureRandom.hex(6)}", exibir_no_site_flag: false)
    habitation.create_address!(
      logradouro: "Rua Site Flag",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: habitation.titulo_anuncio,
        exibir_no_site_flag: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.exibir_no_site_flag).to be(true)

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: habitation.titulo_anuncio,
        exibir_no_site_flag: "0"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.exibir_no_site_flag).to be(false)
  end

  it "oculta classificação de fotos da ficha de pré-cadastro do corretor" do
    broker_profile = Profile.create!(
      name: "Corretor #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: broker,
      codigo: "FOTO-COR-#{SecureRandom.hex(6)}",
      intake_status: "returned_to_broker"
    )

    sign_in broker
    get edit_admin_habitation_path(intake)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Classificação das Fotos:")
  end

  it "abre cadastro de proprietário em modal no formulário do imóvel" do
    habitation = create(:habitation, codigo: "PROP-MODAL-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="quickProprietorModal"')
    expect(response.body).to include(new_admin_proprietor_path(embed: "modal"))
    expect(response.body).not_to include('title="Cadastrar novo proprietário" target="_blank"')
  end

  it "permite captador visualizar documentos sem anexar ou remover" do
    broker_profile = Profile.create!(
      name: "Corretor docs #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(:habitation, :broker_intake, admin_user: broker, codigo: "DOC-COR-#{SecureRandom.hex(6)}", intake_status: "returned_to_broker")
    habitation.fichas_cadastro.attach(
      io: StringIO.new("ficha"),
      filename: "ficha.txt",
      content_type: "text/plain"
    )
    attachment = habitation.fichas_cadastro.attachments.first

    sign_in broker
    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ficha.txt")
    expect(response.body).not_to include("Adicionar arquivos")
    expect(response.body).not_to include(purge_attachment_admin_habitation_path(habitation, association: "fichas_cadastro", attachment_id: attachment.id))

    delete purge_attachment_admin_habitation_path(habitation, association: "fichas_cadastro", attachment_id: attachment.id)

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "documents"))
    expect(habitation.reload.fichas_cadastro.attachments.count).to eq(1)
  end

  it "registra auditoria de alteração do imóvel e exibe o botão de timeline" do
    habitation = create(:habitation, codigo: "AUD-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo", exibir_no_site_flag: false)
    habitation.create_address!(
      logradouro: "Rua Auditoria",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    expect {
      patch admin_habitation_path(habitation), params: {
        habitation: {
          titulo_anuncio: "Título novo",
          valor_venda_formatted: "950.000,00",
          exibir_no_site_flag: "1"
        }
      }
    }.to change(HabitationAuditLog, :count).by(1)

    expect(response).to redirect_to(admin_habitations_path)
    log = HabitationAuditLog.last
    expect(log).to have_attributes(habitation_id: habitation.id, admin_user_id: admin.id, action: "published")
    expect(log.changed_fields).to include("titulo_anuncio", "valor_venda_cents", "exibir_no_site_flag")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Timeline")
    expect(response.body).to include("Título do anúncio")
    expect(response.body).to include("Título antigo")
    expect(response.body).to include("Título novo")
  end

  it "exibe eventos importados do Vista na timeline do cadastro" do
    habitation = create(:habitation, codigo: "VISTA-TL-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel com timeline Vista")
    HabitationInteraction.create!(
      habitation: habitation,
      admin_user: admin,
      source_table: "VISTA_API_PRONTUARIO",
      source_key: "#{habitation.codigo}:123",
      vista_habitation_code: habitation.codigo,
      subject: "Atualização importada do Vista",
      body: "Descrição alterada no prontuário",
      status: "Concluído",
      occurred_at: Time.zone.parse("2026-06-01 10:30")
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vista")
    expect(response.body).to include("Atualização importada do Vista")
    expect(response.body).to include("Descrição alterada no prontuário")
    expect(response.body).to include("VISTA_API_PRONTUARIO")
  end

  it "exibe documentos importados do Vista na aba de documentos" do
    habitation = create(:habitation, codigo: "VISTA-DOC-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel com documento Vista")
    batch = VistaImportBatch.create!(dump_dir: "spec/vista", status: "completed")
    VistaFileAsset.create!(
      vista_import_batch: batch,
      habitation: habitation,
      table_name: "API_DOCUMENTOS",
      kind: "property_document",
      status: "pending",
      codigo_imovel: habitation.codigo,
      source_path: "documentos/#{habitation.codigo}/autorizacao.pdf",
      source_url: "https://arquivos.example.test/autorizacao.pdf",
      filename: "autorizacao-vista.pdf",
      active_storage_name: "autorizacoes_venda"
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Documentos do Vista")
    expect(response.body).to include("autorizacao-vista.pdf")
    expect(response.body).to include("Pendente de download")
    expect(response.body).to include("https://arquivos.example.test/autorizacao.pdf")
  end

  it "registra qualquer campo do cadastro do imóvel, mesmo fora da lista principal" do
    habitation = create(:habitation, codigo: "AUD-FULL-#{SecureRandom.hex(6)}", festival_salute_flag: false, ocupacao_status: "Desocupado")
    habitation.create_address!(
      logradouro: "Rua Auditoria",
      numero: "20",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        festival_salute_flag: "1",
        ocupacao_status: "Ocupado",
        address_attributes: {
          id: habitation.address.id,
          logradouro: "Rua Auditoria Atualizada",
          numero: "20",
          bairro: "Centro",
          cidade: "Balneário Camboriú",
          uf: "SC"
        }
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    log = HabitationAuditLog.where(habitation_id: habitation.id).last
    expect(log.changed_fields).to include("festival_salute_flag", "ocupacao_status", "address.logradouro")

    get edit_admin_habitation_path(habitation)

    expect(response.body).to include("Festival salute flag")
    expect(response.body).to include("Ocupacao status")
    expect(response.body).to include("Rua Auditoria Atualizada")
  end

  it "registra uploads e remoções de fotos e documentos no histórico" do
    habitation = create(:habitation, codigo: "AUD-DOC-#{SecureRandom.hex(6)}")
    habitation.create_address!(
      logradouro: "Rua Documentos",
      numero: "30",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    file = Tempfile.new(["autorizacao", ".txt"])
    file.write("autorizacao")
    file.rewind

    expect {
      patch admin_habitation_path(habitation), params: {
        habitation: {
          autorizacoes_venda: [
            Rack::Test::UploadedFile.new(file.path, "text/plain")
          ]
        }
      }
    }.to change(HabitationAuditLog, :count).by(1)

    expect(response).to redirect_to(admin_habitations_path)
    upload_log = HabitationAuditLog.last
    expect(upload_log).to have_attributes(action: "attachments_changed")
    expect(upload_log.changed_fields).to include("autorizacoes_venda_attachments")

    attachment = habitation.reload.autorizacoes_venda.attachments.first
    expect {
      delete "/admin/habitations/#{habitation.id}/purge_attachment/autorizacoes_venda/#{attachment.id}"
    }.to change(HabitationAuditLog, :count).by(1)

    remove_log = HabitationAuditLog.last
    expect(remove_log).to have_attributes(action: "attachments_changed")
    expect(remove_log.changed_fields).to include("autorizacoes_venda_attachments")
    expect(remove_log.change_summaries.first[:before]).to include("autorizacao")
  ensure
    file&.close
    file&.unlink
  end

  it "registra vínculo de corretores e publicação em massa no histórico" do
    broker = create(:admin_user, name: "Corretor Auditor")
    habitation = create(:habitation, codigo: "AUD-BULK-#{SecureRandom.hex(6)}", exibir_no_site_flag: false)
    habitation.create_address!(
      logradouro: "Rua Massa",
      numero: "40",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        broker_assignments_attributes: {
          "0" => {
            admin_user_id: broker.id,
            role: "captador",
            commission_type: "percentage",
            commission_value: "2.5"
          }
        }
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    broker_log = HabitationAuditLog.where(habitation_id: habitation.id).last
    expect(broker_log).to have_attributes(action: "broker_assignments_changed")
    expect(broker_log.changed_fields).to include("broker_assignments")
    expect(broker_log.change_summaries.first[:after]).to include("Corretor Auditor")

    expect {
      post bulk_publish_admin_habitations_path, params: {
        selected_ids: [habitation.id],
        action_type: "publicar",
        channels: %w[site]
      }
    }.to change(HabitationAuditLog, :count).by(1)

    bulk_log = HabitationAuditLog.last
    expect(bulk_log).to have_attributes(action: "bulk_updated", habitation_id: habitation.id)
    expect(bulk_log.changed_fields).to include("exibir_no_site_flag")
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

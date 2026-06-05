require "rails_helper"
require "tempfile"

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

  it "registra auditoria de alteração do imóvel e exibe o botão de histórico" do
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
    expect(response.body).to include("Histórico")
    expect(response.body).to include("Título do anúncio")
    expect(response.body).to include("Título antigo")
    expect(response.body).to include("Título novo")
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
    habitation = create(:habitation, codigo: "AUD-BULK-#{SecureRandom.hex(6)}", exibir_no_site_flag: false, publicar_loft: false)
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
        channels: %w[site loft]
      }
    }.to change(HabitationAuditLog, :count).by(1)

    bulk_log = HabitationAuditLog.last
    expect(bulk_log).to have_attributes(action: "bulk_updated", habitation_id: habitation.id)
    expect(bulk_log.changed_fields).to include("exibir_no_site_flag", "publicar_loft")
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

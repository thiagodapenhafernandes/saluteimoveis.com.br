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

  it "separa captações restritas da listagem geral de imóveis" do
    draft = create(:habitation, :broker_intake, admin_user: admin, codigo: "DRAFT-#{SecureRandom.hex(6)}", titulo_anuncio: "Captação em rascunho")
    submitted = create(:habitation, :broker_intake, admin_user: admin, codigo: "REV-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review", titulo_anuncio: "Captação finalizada")
    approved = create(:habitation, :broker_intake, admin_user: admin, codigo: "APP-#{SecureRandom.hex(6)}", intake_status: "admin_approved", titulo_anuncio: "Captação aprovada")
    internal = create(:habitation, :broker_intake, admin_user: admin, codigo: "INT-#{SecureRandom.hex(6)}", intake_status: "internal", titulo_anuncio: "Captação interna")
    published = create(:habitation, :broker_intake, admin_user: admin, codigo: "PUB-#{SecureRandom.hex(6)}", intake_status: "published", titulo_anuncio: "Captação publicada")

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pendente de revisão")
    expect(response.body).to include(internal.titulo_anuncio)
    expect(response.body).to include(published.titulo_anuncio)
    expect(response.body).not_to include(submitted.titulo_anuncio)
    expect(response.body).not_to include(approved.titulo_anuncio)
    expect(response.body).not_to include(draft.titulo_anuncio)

    get admin_habitations_path(intake_review: "pending", ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(submitted.titulo_anuncio)
    expect(response.body).to include(approved.titulo_anuncio)
    expect(response.body).not_to include(draft.titulo_anuncio)
    expect(response.body).not_to include(internal.titulo_anuncio)
    expect(response.body).not_to include(published.titulo_anuncio)
  end

  it "exibe notificação no card quando o preço do imóvel foi alterado" do
    habitation = create(
      :habitation,
      codigo: "PRICE-NOTIFY-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento com preço atualizado",
      valor_venda_cents: 900_000_00
    )
    create(
      :habitation_audit_log,
      habitation: habitation,
      admin_user: admin,
      changed_fields: ["valor_venda_cents"],
      changeset: {
        "valor_venda_cents" => {
          "before" => 1_000_000_00,
          "after" => 900_000_00
        }
      },
      created_at: 2.hours.ago
    )

    get admin_habitations_path(referencia: habitation.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Preço atualizado há")
    expect(response.body).to include("Venda: R$ 1.000.000,00 -&gt; R$ 900.000,00")
  end

  it "mostra para o corretor somente suas captações aguardando aceite" do
    broker_profile = Profile.create!(
      name: "Corretor revisão #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    luciana = create(:admin_user, profile: broker_profile, name: "Luciana Indalécio")
    patricia = create(:admin_user, profile: broker_profile, name: "Patrícia Paula")
    own_waiting = create(:habitation, :broker_intake, admin_user: luciana, codigo: "OWN-REV-#{SecureRandom.hex(6)}", intake_status: "admin_approved", titulo_anuncio: "Aguardando aceite Luciana")
    other_waiting = create(:habitation, :broker_intake, admin_user: patricia, codigo: "OTH-REV-#{SecureRandom.hex(6)}", intake_status: "admin_approved", titulo_anuncio: "Aguardando aceite Patrícia")
    submitted = create(:habitation, :broker_intake, admin_user: luciana, codigo: "SUB-REV-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review", titulo_anuncio: "Em revisão administrativa Luciana")

    sign_in luciana
    get admin_habitations_path(intake_review: "pending", ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_waiting.titulo_anuncio)
    expect(response.body).not_to include(other_waiting.titulo_anuncio)
    expect(response.body).not_to include(submitted.titulo_anuncio)
    expect(response.body).to include("Aguardando aceite do corretor")
  end

  it "mostra ao administrativo somente o que está em revisão administrativa" do
    administrative_profile = Profile.create!(
      name: "Administrativo",
      permissions: Profile.default_permissions_for("Administrativo")
    )
    administrativo = create(:admin_user, profile: administrative_profile, name: "Administrativo Salute")
    submitted = create(:habitation, :broker_intake, admin_user: admin, codigo: "ADM-SUB-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review", titulo_anuncio: "Ficha aguardando revisão #{SecureRandom.hex(4)}")
    approved = create(:habitation, :broker_intake, admin_user: admin, codigo: "ADM-APP-#{SecureRandom.hex(6)}", intake_status: "admin_approved", titulo_anuncio: "Ficha já aprovada #{SecureRandom.hex(4)}")

    sign_in administrativo
    get admin_habitations_path(intake_review: "pending", ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(submitted.titulo_anuncio)
    expect(response.body).not_to include(approved.titulo_anuncio)
  end

  it "lista pendente de revisão para o gerente sem erro de SQL (DISTINCT + ORDER BY)" do
    gerente_profile = Profile.find_or_create_by!(name: "Gerente") do |p|
      p.permissions = Profile.default_permissions_for("Gerente")
    end
    gerente = create(:admin_user, profile: gerente_profile, name: "Marcela Gerente", acting_type: "both")
    membro = create(:admin_user, manager_id: gerente.id, name: "Corretor do time", acting_type: "both")
    intake = create(:habitation, :broker_intake, admin_user: membro, intake_status: "submitted_for_admin_review", codigo: "PEND-#{SecureRandom.hex(6)}", titulo_anuncio: "Ficha do time aguardando revisão")

    sign_in gerente
    get admin_habitations_path(intake_review: "pending", ownership: "all", referencia: "")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(intake.titulo_anuncio)
  end

  it "exibe ações de ficha de papel no novo cadastro administrativo" do
    get new_admin_habitation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('novalidate="novalidate"')
    expect(response.body).to include("Enviar para corretor")
    expect(response.body).to include("Salvar Interno")
    expect(response.body).to include("Salvar")
    expect(response.body).to include("Salvar e sair")
  end

  it "centraliza a edição de preço nos campos principais do bloco comercial" do
    get new_admin_habitation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reduções são registradas automaticamente")
    expect(response.body).to include("Venda anterior")
    expect(response.body).to include("Aluguel anterior")
    expect(response.body).not_to include("Valor promocional")
    expect(response.body).not_to include("Valor Promocional")
    expect(response.body).not_to include("Venda atual")
  end

  it "renderiza permuta por tipo e parcelamento sem checkbox geral duplicado" do
    get new_admin_habitation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aceita permuta imóvel")
    expect(response.body).to include("Características do imóvel aceito na permuta")
    expect(response.body).to include("Aceita permuta veículo")
    expect(response.body).to include("Dados do veículo aceito na permuta")
    expect(response.body).to include("Aceita Parcelamento")
    expect(response.body).to include("Em quantas vezes?")
    expect(response.body).not_to include('name="habitation[aceita_permuta_flag]"')
  end

  it "persiste permuta pelos seletores específicos e parcelamento no formulário completo" do
    habitation = create(
      :habitation,
      codigo: "PERM-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Casa com permuta controlada",
      descricao_web: "Descrição completa do imóvel para validação do formulário.",
      aceita_permuta_flag: false
    )
    habitation.create_address!(
      logradouro: "Rua Permuta #{SecureRandom.hex(4)}",
      numero: "101",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: "88330-000"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: habitation.titulo_anuncio,
        descricao_web: habitation.descricao_web,
        aceita_permuta_imovel_flag: "1",
        aceita_permuta_veiculo_flag: "0",
        aceita_permuta_outros_flag: "0",
        permuta_localizacao: "Balneário Camboriú",
        aceita_parcelamento_flag: "1",
        numero_prestacoes: "24"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.aceita_permuta_flag).to be(true)
    expect(habitation.aceita_permuta_answer).to eq("sim")
    expect(habitation.aceita_permuta_imovel_flag).to be(true)
    expect(habitation.aceita_permuta_veiculo_flag).to be(false)
    expect(habitation.aceita_parcelamento_flag).to be(true)
    expect(habitation.numero_prestacoes).to eq(24)
  end

  it "desliga o flag geral de permuta quando todos os tipos são desmarcados" do
    habitation = create(
      :habitation,
      codigo: "PERM-OFF-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Casa com permuta para desligar",
      descricao_web: "Descrição completa do imóvel para validação do formulário.",
      aceita_permuta_flag: true,
      aceita_permuta_answer: "sim",
      aceita_permuta_imovel_flag: true,
      aceita_permuta_veiculo_flag: true
    )
    habitation.create_address!(
      logradouro: "Rua Permuta Off #{SecureRandom.hex(4)}",
      numero: "202",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: "88330-000"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: habitation.titulo_anuncio,
        descricao_web: habitation.descricao_web,
        aceita_permuta_imovel_flag: "0",
        aceita_permuta_veiculo_flag: "0",
        aceita_permuta_outros_flag: "0"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.aceita_permuta_flag).to be(false)
    expect(habitation.aceita_permuta_answer).to eq("nao")
  end

  it "mantém cadastro administrativo vinculado a corretor em revisão ao salvar sem concluir" do
    broker = create(:admin_user, name: "Adriana Stark")

    expect {
      post admin_habitations_path, params: {
        save_navigation: "exit",
        habitation: {
          admin_user_id: broker.id,
          categoria: "Apartamento",
          status: "Venda",
          tipo: "Unitário",
          titulo_anuncio: "Apartamento à venda 3 suítes no Centro de Itapema",
          address_attributes: {
            logradouro: "Governador Celso Ramos",
            numero: "00",
            complemento: "3701",
            bairro: "Centro",
            cidade: "Itapema",
            uf: "SC",
            cep: "88220-000"
          }
        }
      }
    }.to change(Habitation, :count).by(1)

    expect(response).to redirect_to(admin_habitations_path)
    habitation = Habitation.order(:created_at).last
    expect(habitation).to have_attributes(
      intake_origin: Habitation::INTAKE_ORIGIN_BROKER,
      intake_status: "submitted_for_admin_review",
      intake_step: "review",
      admin_user_id: broker.id,
      exibir_no_site_flag: false
    )
    expect(habitation.submitted_for_review_at).to be_present
  end

  it "mantém o novo cadastro administrativo na própria ficha ao salvar sem indicar saída" do
    expect {
      post admin_habitations_path, params: {
        habitation: {
          categoria: "Apartamento",
          status: "Venda",
          tipo: "Unitário",
          titulo_anuncio: "Casa em Condomínio para teste de permanência",
          address_attributes: {
            logradouro: "Rua Permanecer",
            numero: "101",
            bairro: "Centro",
            cidade: "Balneário Camboriú",
            uf: "SC",
            cep: "88330-000"
          }
        }
      }
    }.to change(Habitation, :count).by(1)

    habitation = Habitation.order(:created_at).last
    expect(response).to redirect_to(edit_admin_habitation_path(habitation))
    expect(habitation).to have_attributes(
      intake_origin: Habitation::INTAKE_ORIGIN_BROKER,
      intake_status: "submitted_for_admin_review"
    )
  end

  it "permite salvar cadastro interno pela metade sem categoria e o envia para revisão" do
    expect {
      post admin_habitations_path, params: {
        habitation: {
          status: "Venda",
          tipo: "Unitário",
          titulo_anuncio: "Ficha de papel pela metade #{SecureRandom.hex(4)}",
          address_attributes: {
            logradouro: "Rua Sem Categoria",
            numero: "200",
            bairro: "Centro",
            cidade: "Itapema",
            uf: "SC",
            cep: "88220-000"
          }
        }
      }
    }.to change(Habitation, :count).by(1)

    habitation = Habitation.order(:created_at).last
    expect(habitation.categoria).to be_blank
    expect(habitation.intake_status).to eq("submitted_for_admin_review")
  end

  it "mantém ações de revisão administrativa vinculadas ao formulário principal" do
    habitation = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      intake_status: "submitted_for_admin_review",
      codigo: "REV-ACTION-#{SecureRandom.hex(6)}"
    )

    return_path = admin_habitations_path(ownership: "all", q: habitation.codigo)

    get edit_admin_habitation_path(habitation, return_to: return_path)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="admin_habitation_form"')
    expect(response.body).to include('data-turbo="false"')
    expect(response.body).to include('name="release_to_broker_after_save"')
    expect(response.body).to include('name="save_internal_after_save"')
    expect(response.body.scan('form="admin_habitation_form"').size).to be >= 4
  end

  it "sincroniza o aluguel editável entre Visão geral e Comercial" do
    habitation = create(
      :habitation,
      codigo: "RENT-SYNC-#{SecureRandom.hex(6)}",
      status: "Aluguel",
      valor_locacao_cents: 440_000
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    rent_inputs = document.css('input[name="habitation[valor_locacao_formatted]"]')

    expect(rent_inputs.size).to eq(2)
    expect(rent_inputs.map { |input| input["data-habitation-form-sync-field"] }).to all(eq("valor_locacao_formatted"))
    expect(rent_inputs.map { |input| input["data-action"].to_s }).to all(include("input->habitation-form#syncMirroredField"))
  end

  it "exibe salvamento dedicado para fotos no cadastro do imóvel" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "PHOTO-DEV-#{SecureRandom.hex(6)}",
      nome_empreendimento: "Residencial Fotos"
    )
    habitation = create(:habitation, codigo: "PHOTO-BTN-#{SecureRandom.hex(6)}", codigo_empreendimento: development.codigo)

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Salvar fotos")
    expect(response.body).to include(update_photos_admin_habitation_path(habitation))
    expect(response.body).to include('data-photo-upload-target="dirtyStatus"')
    expect(response.body).to include("media-photo-image")
    expect(response.body).to include('class="media-development-toggle form-check form-switch mb-0"')
    expect(response.body).to include('data-photo-upload-target="developmentPhotosSwitch"')
    expect(response.body).to include("Foto original importada da API do Vista")
  end

  it "mantém compartilhamento disponível ao visualizar o cadastro do imóvel" do
    habitation = create(:habitation, codigo: "SHARE-SHOW-#{SecureRandom.hex(6)}")

    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="broker-share"')
    expect(response.body).to include(share_link_habitation_path(habitation))
    expect(response.body).to include("Compartilhar imóvel")
    expect(response.body).to include("broker-share--toolbar")
  end

  it "mostra as observações internas na visualização para admin e para corretor" do
    broker_profile = Profile.create!(
      name: "Corretor obs #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    corretor = create(:admin_user, profile: broker_profile, name: "Corretor Observações")
    habitation = create(
      :habitation,
      admin_user: corretor,
      codigo: "OBS-SHOW-#{SecureRandom.hex(6)}",
      observacoes: "Não colocar no site. Proprietária: Claudia -41 99223.3802"
    )

    sign_in admin
    get admin_habitation_path(habitation)
    expect(response.body).to include("Observações internas")
    expect(response.body).to include("Não colocar no site")

    sign_in corretor
    get admin_habitation_path(habitation)
    expect(response.body).to include("Não colocar no site")
  end

  it "não exibe o captador responsável pelo cadastro na seção de responsáveis do formulário" do
    sign_in admin
    habitation = create(:habitation, admin_user: admin, codigo: "RESP-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Responsáveis & Agenciamento")
    expect(response.body).not_to include("Captador responsável pelo cadastro do imóvel")
  end

  it "organiza os filtros do catálogo em accordions com Valor no topo e chips ajustados" do
    sign_in admin
    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("filter-accordion")
    expect(response.body).to include("Localização")
    expect(response.body).to include("Negociação")
    expect(response.body).to include("Características apartamento")
    expect(response.body).to include("Características empreendimento")
    expect(response.body).to include("Administrativo")
    # chips novos
    expect(response.body).to include("Quadra Mar")
    expect(response.body).to include("Vista Mar")
    # Valor (min/max) no topo
    expect(response.body).to include('name="min_price"')
    expect(response.body).to include('name="max_price"')
    html = Nokogiri::HTML(response.body)
    min_price_input = html.at_css('input[name="min_price"]')
    max_price_input = html.at_css('input[name="max_price"]')

    expect(min_price_input["data-controller"]).to eq("currency-mask")
    expect(max_price_input["data-controller"]).to eq("currency-mask")
    expect(min_price_input["autocomplete"]).to eq("off")
    expect(max_price_input["autocomplete"]).to eq("off")
  end

  it "mantém compartilhamento disponível ao editar o cadastro do imóvel" do
    habitation = create(:habitation, codigo: "SHARE-EDIT-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="broker-share"')
    expect(response.body).to include(share_link_habitation_path(habitation))
    expect(response.body).to include("Compartilhar imóvel")
    expect(response.body).to include("broker-share--toolbar")
  end

  it "exibe Administração de locação feita pela Salute no bloco de valores do detalhe administrativo" do
    habitation = create(
      :habitation,
      codigo: "SHOW-ADMIN-MGMT-#{SecureRandom.hex(6)}",
      status: "Aluguel",
      valor_locacao_cents: 3_000_00,
      valor_condominio_cents: 280_00,
      valor_iptu_cents: 786_00,
      aceita_financiamento_flag: false,
      aceita_permuta_flag: false,
      salute_rental_management_answer: "sim"
    )

    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Valores")
    expect(response.body).to include("Administração de locação feita pela Salute")
    expect(response.body).to include("Sim")
    expect(response.body).to include("Aceita permuta")
  end

  it "abre o cadastro quando existe arquivo não-imagem anexado como foto" do
    habitation = create(:habitation, codigo: "PHOTO-ZIP-#{SecureRandom.hex(6)}")
    habitation.photos.attach(
      io: StringIO.new("zip-content"),
      filename: "fotos-originais.zip",
      content_type: "application/zip"
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("fotos-originais.zip")
    expect(response.body).to include("bi-file-earmark-zip")
  end

  it "salva ordem e visibilidade das fotos pelo endpoint dedicado" do
    first_url = "https://example.com/first.jpg"
    second_url = "https://example.com/second.jpg"
    habitation = create(
      :habitation,
      codigo: "PHOTO-SAVE-#{SecureRandom.hex(6)}",
      pictures: [
        { "url" => first_url, "ordem" => 1 },
        { "url" => second_url, "ordem" => 2 }
      ]
    )

    patch update_photos_admin_habitation_path(habitation), params: {
      habitation: {
        ordered_picture_indices: "0,1",
        site_hidden_picture_urls: second_url,
        picture_environment_assignments: {
          first_url => "Cozinha",
          second_url => "Fachada"
        },
        foto_classificacao: "Profissionais"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "media"))
    habitation.reload
    expect(habitation.pictures.map { |picture| picture["url"] }).to eq([second_url, first_url])
    expect(habitation.pictures.map { |picture| picture["ambiente"] }).to eq(["Fachada", "Cozinha"])
    expect(habitation.pictures.first["site_hidden"]).to eq(true)
    expect(habitation.pictures.second["site_hidden"]).to eq(false)
    expect(habitation.foto_classificacao).to eq("Profissionais")
  end

  it "não inclui ações de exclusão de anexos como método do formulário principal" do
    habitation = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      intake_status: "submitted_for_admin_review",
      codigo: "REV-DOC-#{SecureRandom.hex(6)}"
    )
    habitation.fichas_cadastro.attach(
      io: StringIO.new("ficha"),
      filename: "ficha.txt",
      content_type: "text/plain"
    )
    habitation.autorizacoes_venda.attach(
      io: StringIO.new("autorizacao"),
      filename: "autorizacao.txt",
      content_type: "text/plain"
    )

    return_path = admin_habitations_path(ownership: "all", q: habitation.codigo)

    get edit_admin_habitation_path(habitation, return_to: return_path)

    expect(response).to have_http_status(:ok)
    form_markup = response.body[/<form[^>]*id="admin_habitation_form"[\s\S]*?<\/form>/]
    expect(form_markup).to be_present
    expect(form_markup.scan("<form").size).to eq(1)
    expect(form_markup).not_to include('name="_method" value="delete"')

    ficha_attachment = habitation.fichas_cadastro.attachments.first
    authorization_attachment = habitation.autorizacoes_venda.attachments.first
    expect(response.body).to include(%(form="purge_attachment_#{ficha_attachment.id}"))
    expect(response.body).to include(%(form="purge_attachment_#{authorization_attachment.id}"))
    expect(response.body).to include(%(id="purge_attachment_#{ficha_attachment.id}"))
    expect(response.body).to include(%(id="purge_attachment_#{authorization_attachment.id}"))
    expect(response.body).to include('name="_method" value="delete"')
    [ficha_attachment, authorization_attachment].each do |attachment|
      purge_form_markup = response.body[/<form[^>]*id="purge_attachment_#{attachment.id}"[\s\S]*?<\/form>/]
      expect(purge_form_markup).to be_present
      expect(purge_form_markup).to include('name="return_to"')
      expect(purge_form_markup).to include(%(value="#{CGI.escapeHTML(return_path)}"))
    end
    expect(response.body).to include(purge_attachment_admin_habitation_path(habitation, association: "fichas_cadastro", attachment_id: ficha_attachment.id))
    expect(response.body).to include(purge_attachment_admin_habitation_path(habitation, association: "autorizacoes_venda", attachment_id: authorization_attachment.id))
  end

  it "exibe no topo o captador vindo dos responsáveis e agenciamento" do
    captador = create(:admin_user, name: "Luciana Indalécio")
    habitation = create(
      :habitation,
      admin_user: nil,
      codigo: "CAP-TOP-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel com captador por vínculo"
    )
    habitation.broker_assignments.create!(admin_user: captador, role: "captador")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Captador")
    expect(response.body).to include("Luciana Indalécio")
    expect(response.body).not_to include("Corretor responsável:")
  end

  it "exibe nome do empreendimento no cadastro do tipo empreendimento" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "54",
      nome_empreendimento: "Empreendimento Centro Cod. 54"
    )

    get edit_admin_habitation_path(development)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Pesquisar por código/referência")
    expect(response.body).to include("Nome do empreendimento:")
    expect(response.body).to include("Empreendimento Centro Cod. 54")
  end

  it "filtra por referência na listagem sem buscar número de rua ou prédio" do
    reference_match = create(
      :habitation,
      codigo: "8615",
      titulo_anuncio: "Imóvel correto por referência",
      numero: "999"
    )
    address_number_match = create(
      :habitation,
      codigo: "9999",
      titulo_anuncio: "Imóvel que só bate no número do endereço",
      numero: "8615"
    )

    get admin_habitations_path(ownership: "all", referencia: "8615")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Código / referência")
    expect(response.body).to include(reference_match.titulo_anuncio)
    expect(response.body).not_to include(address_number_match.titulo_anuncio)
  end

  it "abre o cadastro pesquisando pelo código" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "54",
      nome_empreendimento: "Empreendimento Centro Cod. 54"
    )

    get search_by_code_admin_habitations_path(codigo: "54")

    expect(response).to redirect_to(edit_admin_habitation_path(development))
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

  it "usa venda, aluguel e diária como status padrão e abre todos quando o filtro status Todos é enviado" do
    active = create(:habitation, codigo: "ATIVO-#{SecureRandom.hex(6)}", status: "Venda", titulo_anuncio: "Imóvel ativo visível")
    rental = create(:habitation, codigo: "ALUGUEL-#{SecureRandom.hex(6)}", status: "Aluguel", titulo_anuncio: "Imóvel aluguel visível")
    daily = create(:habitation, codigo: "DIARIA-#{SecureRandom.hex(6)}", status: "Diária", titulo_anuncio: "Imóvel diária visível")
    sold = create(:habitation, codigo: "VENDIDO-#{SecureRandom.hex(6)}", status: "Vendido terceiros", titulo_anuncio: "Imóvel vendido oculto", imovel_dwv: "Sim")
    rented = create(:habitation, codigo: "ALUGADO-#{SecureRandom.hex(6)}", status: "Alugado terceiros", titulo_anuncio: "Imóvel alugado oculto")

    get admin_habitations_path(ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(active.titulo_anuncio)
    expect(response.body).to include(rental.titulo_anuncio)
    expect(response.body).to include(daily.titulo_anuncio)
    expect(response.body).not_to include(sold.titulo_anuncio)
    expect(response.body).not_to include(rented.titulo_anuncio)

    get admin_habitations_path(ownership: "all", status: "")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(active.titulo_anuncio)
    expect(response.body).to include(rental.titulo_anuncio)
    expect(response.body).to include(daily.titulo_anuncio)
    expect(response.body).to include(sold.titulo_anuncio)
    expect(response.body).to include(rented.titulo_anuncio)

    get admin_habitations_path(ownership: "all", status: "Vendido terceiros")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(sold.titulo_anuncio)
  end

  it "exibe imóvel com status inativo ao pesquisar pela referência" do
    rented = create(:habitation, codigo: "REF-INATIVO-#{SecureRandom.hex(6)}", status: "Alugado terceiros", titulo_anuncio: "Alugado mas buscável por código #{SecureRandom.hex(4)}")

    get admin_habitations_path(ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(rented.titulo_anuncio)

    get admin_habitations_path(ownership: "all", referencia: rented.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(rented.titulo_anuncio)
  end

  it "filtra dormitórios por faixa mínima e máxima" do
    d1 = create(:habitation, codigo: "DOR1-#{SecureRandom.hex(6)}", status: "Venda", dormitorios_qtd: 1, titulo_anuncio: "Um dormitório #{SecureRandom.hex(4)}")
    d3 = create(:habitation, codigo: "DOR3-#{SecureRandom.hex(6)}", status: "Venda", dormitorios_qtd: 3, titulo_anuncio: "Três dormitórios #{SecureRandom.hex(4)}")
    d5 = create(:habitation, codigo: "DOR5-#{SecureRandom.hex(6)}", status: "Venda", dormitorios_qtd: 5, titulo_anuncio: "Cinco dormitórios #{SecureRandom.hex(4)}")

    get admin_habitations_path(ownership: "all", dorms_min: 2, dorms_max: 4)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(d3.titulo_anuncio)
    expect(response.body).not_to include(d1.titulo_anuncio)
    expect(response.body).not_to include(d5.titulo_anuncio)
  end

  it "não duplica bairros por maiúscula/minúscula no select do cadastro" do
    h1 = create(:habitation, codigo: "BV1-#{SecureRandom.hex(6)}", status: "Venda")
    h1.create_address!(logradouro: "R A", numero: "1", bairro: "Praia Brava", cidade: "Itajaí", uf: "SC")
    h2 = create(:habitation, codigo: "BV2-#{SecureRandom.hex(6)}", status: "Venda")
    h2.create_address!(logradouro: "R B", numero: "2", bairro: "praia brava", cidade: "Itajaí", uf: "SC")
    target = create(:habitation, codigo: "TGT-#{SecureRandom.hex(6)}", status: "Venda")

    get edit_admin_habitation_path(target)

    expect(response).to have_http_status(:ok)
    bairro_select = Nokogiri::HTML(response.body).at_css('select[name="habitation[address_attributes][bairro]"]')
    expect(bairro_select).to be_present
    matches = bairro_select.css("option").map { |option| I18n.transliterate(option.text).downcase.strip }.select { |text| text == "praia brava" }
    expect(matches.size).to eq(1)
  end

  it "não duplica cidade no filtro por variação de acento ou caixa" do
    h1 = create(:habitation, codigo: "BC1-#{SecureRandom.hex(6)}", status: "Venda")
    h1.create_address!(logradouro: "Rua A", numero: "1", bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")
    h2 = create(:habitation, codigo: "BC2-#{SecureRandom.hex(6)}", status: "Venda")
    h2.create_address!(logradouro: "Rua B", numero: "2", bairro: "Centro", cidade: "Balneario Camboriu", uf: "SC")

    get admin_habitations_path(ownership: "all")

    expect(response).to have_http_status(:ok)
    cidade_select = Nokogiri::HTML(response.body).at_css('select[name="cidade[]"]')
    expect(cidade_select).to be_present
    matches = cidade_select.css("option").map { |option| I18n.transliterate(option.text).downcase.strip }.select { |text| text == "balneario camboriu" }
    expect(matches.size).to eq(1)
  end

  it "distingue Semi Mobiliado de totalmente Mobiliado no filtro de características" do
    semi = create(:habitation, codigo: "SEMI-#{SecureRandom.hex(6)}", status: "Aluguel", caracteristicas: ["Semi Mobiliado"], titulo_anuncio: "Imóvel semi mobiliado #{SecureRandom.hex(4)}")
    full = create(:habitation, codigo: "FULL-#{SecureRandom.hex(6)}", status: "Aluguel", caracteristicas: ["Mobiliado"], mobiliado_flag: true, titulo_anuncio: "Imóvel totalmente mobiliado #{SecureRandom.hex(4)}")

    get admin_habitations_path(ownership: "all", amenities: ["Semi Mobiliado"])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(semi.titulo_anuncio)
    expect(response.body).not_to include(full.titulo_anuncio)

    get admin_habitations_path(ownership: "all", amenities: ["Mobiliado"])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(full.titulo_anuncio)
    expect(response.body).not_to include(semi.titulo_anuncio)
  end

  it "traz imóveis do empreendimento mesmo quando têm só o nome (DWV)" do
    empreendimento = create(:habitation, tipo: "Empreendimento", categoria: "Empreendimento", codigo: "CVA-#{SecureRandom.hex(4)}", nome_empreendimento: "Carmel Vista Alta")
    dwv = create(:habitation, codigo: "DWVCVA-#{SecureRandom.hex(4)}", status: "Venda", nome_empreendimento: "Carmel Vista Alta", titulo_anuncio: "Apto DWV Carmel #{SecureRandom.hex(4)}")
    outro = create(:habitation, codigo: "OUTRO-#{SecureRandom.hex(4)}", status: "Venda", nome_empreendimento: "Outro Residencial", titulo_anuncio: "Apto outro empreendimento #{SecureRandom.hex(4)}")

    get admin_habitations_path(ownership: "all", empreendimento_codigo: empreendimento.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(dwv.titulo_anuncio)
    expect(response.body).not_to include(outro.titulo_anuncio)
  end

  it "filtra imóveis pela cidade do proprietário" do
    prop_bc = create(:proprietor, city: "Balneário Camboriú")
    prop_itajai = create(:proprietor, city: "Itajaí")
    in_bc = create(:habitation, codigo: "PROP-BC-#{SecureRandom.hex(6)}", status: "Venda", proprietor: prop_bc, titulo_anuncio: "Imóvel de proprietário em BC #{SecureRandom.hex(4)}")
    in_itajai = create(:habitation, codigo: "PROP-ITJ-#{SecureRandom.hex(6)}", status: "Venda", proprietor: prop_itajai, titulo_anuncio: "Imóvel de proprietário em Itajaí #{SecureRandom.hex(4)}")

    get admin_habitations_path(ownership: "all", proprietor_city: "Balneário Camboriú")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(in_bc.titulo_anuncio)
    expect(response.body).not_to include(in_itajai.titulo_anuncio)
  end

  it "não exibe código DWV no card operacional quando o imóvel tem referência Salute" do
    dwv_property = create(
      :habitation,
      codigo: "8630",
      codigo_dwv: "325054",
      imovel_dwv: "Sim",
      titulo_anuncio: "Imóvel integrado com referência local"
    )

    get admin_habitations_path(ownership: "all", q: dwv_property.codigo)

    expect(response).to have_http_status(:ok)
    card = Nokogiri::HTML(response.body).css(".property-card-horizontal").find { |node| node.text.include?(dwv_property.codigo) }

    expect(card.text).to include("8630")
    expect(card.text).not_to include("325054")
    expect(card.text).not_to include("DWV")
    expect(card.to_html).not_to include("Código DWV")
  end

  it "não exibe empreendimento contaminado nem rótulo Apto para casa standalone" do
    house = create(
      :habitation,
      codigo: "CASA-#{SecureRandom.hex(6)}",
      categoria: "Casa",
      status: "Aluguel",
      titulo_anuncio: "Casa pontual para locação no Centro",
      codigo_empreendimento: nil,
      valor_locacao_cents: 1_200_000
    )
    house.update_columns(codigo_empreendimento: "1027", nome_empreendimento: "Torre Indevida")
    Address.create!(
      addressable: house,
      logradouro: "Rua 2850",
      numero: "581",
      complemento: "1302",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    get admin_habitations_path(ownership: "all", q: house.codigo)

    expect(response).to have_http_status(:ok)
    card = Nokogiri::HTML(response.body).css(".property-card-horizontal").find { |node| node.text.include?(house.codigo) }

    expect(card.text).to include("Casa pontual para locação no Centro")
    expect(card.text).to include("Compl. 1302")
    expect(card.text).not_to include("Torre Indevida")
    expect(card.text).not_to include("Apto. 1302")
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

  it "permite ao corretor encontrar imóveis de um colega ao filtrar por corretor mesmo no escopo Meus imóveis" do
    broker_profile = Profile.create!(
      name: "Corretor filtro #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    luciana = create(:admin_user, profile: broker_profile, name: "Luciana Indalécio")
    patricia = create(:admin_user, profile: broker_profile, name: "Patrícia Paula")
    own_property = create(:habitation, admin_user: luciana, codigo: "OWN-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel da Luciana")
    colleague_property = create(:habitation, admin_user: patricia, codigo: "COL-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel da Patrícia")

    sign_in luciana
    get admin_habitations_path(ownership: "mine", corretor_id: patricia.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(colleague_property.titulo_anuncio)
    expect(response.body).not_to include(own_property.titulo_anuncio)
  end

  it "abre imóvel de Todos no detalhe interno para corretor sem permissão de edição" do
    broker_profile = Profile.create!(
      name: "Corretor todos #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    vera = create(:admin_user, profile: broker_profile, name: "Vera Corretora")
    other_broker = create(:admin_user, profile: broker_profile, name: "Outro Corretor")
    other_property = create(
      :habitation,
      admin_user: other_broker,
      codigo: "TODOS-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel de todos para consulta",
      proprietario: "Proprietário Restrito"
    )

    sign_in vera
    get admin_habitations_path(ownership: "all", q: other_property.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other_property.titulo_anuncio)
    expect(response.body).to include("Captador:")
    expect(response.body).to include(other_broker.name)
    card = Nokogiri::HTML(response.body).css(".property-card-horizontal").find { |node| node.text.include?(other_property.codigo) }
    expect(card["style"]).not_to include("height: 240px")
    anchored_return_path = "#{request.fullpath}#admin_habitation_#{other_property.id}"
    expect(response.body).to include(%(id="admin_habitation_#{other_property.id}"))
    expect(response.body).to include(CGI.escapeHTML(admin_habitation_path(other_property, return_to: anchored_return_path)))
    expect(response.body).not_to include(%(data-clickable-card-url-value="#{CGI.escapeHTML(habitation_path(other_property))}"))

    get admin_habitation_path(other_property, return_to: admin_habitations_path(ownership: "all", q: other_property.codigo))

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Informações principais")
    expect(response.body).to include(other_property.titulo_anuncio)
    expect(response.body).to include("Captador")
    expect(response.body).to include(other_broker.name)
    expect(response.body).not_to include("Proprietário</div>")
    expect(response.body).not_to include("Proprietário Restrito")

    get edit_admin_habitation_path(other_property)

    expect(response).to redirect_to(admin_habitations_path)

    patch admin_habitation_path(other_property), params: {
      habitation: {
        status: "Aluguel",
        valor_venda_formatted: "123.000,00",
        titulo_anuncio: "Tentativa de alteração por outro corretor"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(other_property.reload).to have_attributes(
      status: "Venda",
      titulo_anuncio: "Imóvel de todos para consulta"
    )
    expect(other_property.valor_venda_cents).not_to eq(123_000_00)
  end

  it "exibe contatos do proprietário no cadastro do imóvel para perfil com visualização de proprietários" do
    profile = Profile.create!(
      name: "Gestor proprietários #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Gerente").merge(
        "proprietarios" => { "view" => true, "manage" => false }
      )
    )
    gestor = create(:admin_user, profile: profile, name: "Gestor com Proprietários")
    captador = create(:admin_user, name: "Captador do Imóvel")
    habitation = create(
      :habitation,
      admin_user: captador,
      codigo: "OWNER-VIEW-#{SecureRandom.hex(6)}",
      proprietario: "Proprietário Liberado",
      proprietario_email: "liberado@example.com",
      proprietario_celular: "(47) 99999-1234",
      proprietario_telefone_comercial: "(47) 3333-1234",
      proprietario_telefone_residencial: "(47) 3222-1234"
    )
    habitation.create_address!(
      logradouro: "Rua Proprietário",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    sign_in gestor

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proprietário e contatos")
    expect(response.body).to include("Proprietário Liberado")
    expect(response.body).to include("liberado@example.com")
    expect(response.body).to include("(47) 99999-1234")
    expect(response.body).to include("(47) 3333-1234")
    expect(response.body).to include("(47) 3222-1234")
  end

  it "permite ao corretor editar apenas as imediações do próprio imóvel, mantendo o resto do endereço travado" do
    broker_profile = Profile.create!(
      name: "Corretor imediacoes #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    luciana = create(:admin_user, profile: broker_profile, name: "Luciana Imediações")
    own_property = create(:habitation, admin_user: luciana, codigo: "IMED-#{SecureRandom.hex(6)}")
    Address.create!(
      addressable: own_property,
      tipo_endereco: "Rua",
      logradouro: "2000",
      numero: "120",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC",
      cep: "88330-590",
      imediacoes: []
    )
    own_property.reload

    sign_in luciana
    patch admin_habitation_path(own_property), params: {
      habitation: {
        address_attributes: {
          id: own_property.address.id,
          imediacoes: ["Próximo à praia", "Perto de shopping"],
          bairro: "Bairro Alterado",
          logradouro: "Rua Hackeada"
        }
      }
    }

    own_property.reload
    expect(own_property.address.imediacoes).to contain_exactly("Próximo à praia", "Perto de shopping")
    expect(own_property.address.bairro).to eq("Centro")
    expect(own_property.address.logradouro).to eq("2000")
  end

  it "abre imóvel próprio na aba Todos em visualização interna, não em edição" do
    broker_profile = Profile.create!(
      name: "Corretor todos proprio #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    vera = create(:admin_user, profile: broker_profile, name: "Vera Corretora")
    own_property = create(
      :habitation,
      admin_user: vera,
      codigo: "TODOS-PROP-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel próprio na aba todos"
    )

    sign_in vera
    get admin_habitations_path(ownership: "all", q: own_property.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_property.titulo_anuncio)
    anchored_return_path = "#{request.fullpath}#admin_habitation_#{own_property.id}"
    expect(response.body).to include(CGI.escapeHTML(admin_habitation_path(own_property, return_to: anchored_return_path)))
    expect(response.body).to include(CGI.escapeHTML(edit_admin_habitation_path(own_property, return_to: anchored_return_path)))
  end

  it "permite que corretor filtre imóveis por outro corretor na aba Todos" do
    broker_profile = Profile.create!(
      name: "Corretor filtro #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    luciana = create(:admin_user, profile: broker_profile, name: "Luciana Filtro")
    patricia = create(:admin_user, profile: broker_profile, name: "Patrícia Filtro")
    own_property = create(
      :habitation,
      admin_user: luciana,
      codigo: "FILTRO-OWN-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel da Luciana no filtro"
    )
    other_property = create(
      :habitation,
      admin_user: patricia,
      codigo: "FILTRO-OTHER-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel da Patrícia no filtro"
    )

    sign_in luciana
    get admin_habitations_path(ownership: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="corretor_id"')
    expect(response.body).to include("Patrícia Filtro")
    expect(response.body).not_to include('name="proprietor_id"')
    html = Nokogiri::HTML(response.body)
    primary_filters = html.at_css(".filter-pane-primary")
    advanced_filters = html.at_css(".filter-advanced-body")
    expect(primary_filters.at_css('select[name="empreendimento_codigo"]')).to be_present
    expect(primary_filters.at_css('select[name="corretor_id"]')).to be_present
    expect(advanced_filters&.at_css('select[name="empreendimento_codigo"]')).to be_nil
    expect(advanced_filters&.at_css('select[name="corretor_id"]')).to be_nil

    get admin_habitations_path(ownership: "all", corretor_id: patricia.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other_property.titulo_anuncio)
    expect(response.body).not_to include(own_property.titulo_anuncio)
  end

  it "combina status, categoria e Frente Mar sem trazer imóveis incompatíveis" do
    matching = create(
      :habitation,
      codigo: "FILTRO-OK-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento venda frente mar correto",
      status: "Venda",
      categoria: "Apartamento",
      frente_mar_avenida_atlantica_flag: true
    )
    wrong_category = create(
      :habitation,
      codigo: "FILTRO-CASA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Casa frente mar fora do filtro",
      status: "Venda",
      categoria: "Casa",
      frente_mar_avenida_atlantica_flag: true
    )
    wrong_status = create(
      :habitation,
      codigo: "FILTRO-ALUGUEL-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento aluguel frente mar fora do filtro",
      status: "Aluguel",
      categoria: "Apartamento",
      frente_mar_avenida_atlantica_flag: true
    )
    vista_only = create(
      :habitation,
      codigo: "FILTRO-VISTA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento vista mar não é frente mar",
      status: "Venda",
      categoria: "Apartamento",
      vista_frente_mar_flag: true,
      caracteristicas: ["Vista Mar"]
    )

    get admin_habitations_path(
      ownership: "all",
      status: "Venda",
      categoria: "Apartamento",
      amenities: ["Frente Mar"]
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching.titulo_anuncio)
    expect(response.body).not_to include(wrong_category.titulo_anuncio)
    expect(response.body).not_to include(wrong_status.titulo_anuncio)
    expect(response.body).not_to include(vista_only.titulo_anuncio)
  end

  it "exibe as características residenciais do cadastro nos filtros de apartamento" do
    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    apartment_feature_values = html.css('input[id^="apartment_amenity_filter_"][name="amenities[]"]').map { |input| input["value"] }

    expect(apartment_feature_values).to include(
      "Água quente",
      "Ar-condicionado",
      "Área de serviço",
      "Lavabo",
      "Sacada com churrasqueira",
      "Split"
    )
  end

  it "exibe infraestrutura dinâmica de empreendimento nos filtros do catálogo" do
    AttributeOption.create!(context: "habitation", category: "infrastructure", name: "Cinema")

    get admin_habitations_path

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    enterprise_feature_values = html.css('input[id^="amenity_filter_"][name="amenities[]"]').map { |input| input["value"] }

    expect(enterprise_feature_values).to include("Cinema")
  end

  it "filtra por característica residencial selecionada no bloco de apartamento" do
    matching = create(
      :habitation,
      codigo: "APT-LAVABO-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento com lavabo no filtro",
      categoria: "Apartamento",
      caracteristicas: ["Lavabo"]
    )
    other = create(
      :habitation,
      codigo: "APT-SEM-LAVABO-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento sem lavabo no filtro",
      categoria: "Apartamento",
      caracteristicas: ["Sacada"]
    )

    get admin_habitations_path(ownership: "all", amenities: ["Lavabo"])

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching.titulo_anuncio)
    expect(response.body).not_to include(other.titulo_anuncio)
  end

  it "permite filtrar por múltiplas categorias" do
    apartment = create(
      :habitation,
      codigo: "CAT-APT-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento no filtro múltiplo",
      categoria: "Apartamento"
    )
    house = create(
      :habitation,
      codigo: "CAT-CASA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Casa no filtro múltiplo",
      categoria: "Casa"
    )
    store = create(
      :habitation,
      codigo: "CAT-LOJA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Loja fora do filtro múltiplo",
      categoria: "Loja"
    )

    get admin_habitations_path(ownership: "all", categoria: ["Apartamento", "Casa"])

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    category_select = html.at_css('select[name="categoria[]"]')
    expect(category_select).to be_present
    expect(category_select["multiple"]).to eq("multiple")
    expect(response.body).to include(apartment.titulo_anuncio)
    expect(response.body).to include(house.titulo_anuncio)
    expect(response.body).not_to include(store.titulo_anuncio)
  end

  it "aplica o pill Frente Mar com a mesma regra estrita do checkbox" do
    matching = create(
      :habitation,
      codigo: "PILL-FRENTE-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento pill frente mar correto",
      status: "Venda",
      categoria: "Apartamento Garden",
      caracteristicas: ["Frente Mar"]
    )
    vista_only = create(
      :habitation,
      codigo: "PILL-VISTA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento pill vista mar fora",
      status: "Venda",
      categoria: "Apartamento",
      vista_frente_mar_flag: true,
      caracteristicas: ["Vista Mar"]
    )

    get admin_habitations_path(
      ownership: "all",
      status: "Venda",
      categoria: "Apartamento",
      scope: "frente_mar"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching.titulo_anuncio)
    expect(response.body).not_to include(vista_only.titulo_anuncio)
  end

  it "filtra corretor também pelo responsável principal do imóvel" do
    admin = create(:admin_user, :admin)
    broker = create(:admin_user, name: "Corretor Principal #{SecureRandom.hex(4)}")
    other_broker = create(:admin_user, name: "Outro Corretor #{SecureRandom.hex(4)}")
    owned_by_broker = create(
      :habitation,
      admin_user: broker,
      codigo: "CORRETOR-OK-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel do corretor principal"
    )
    owned_by_other = create(
      :habitation,
      admin_user: other_broker,
      codigo: "CORRETOR-OUTRO-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel de outro corretor"
    )

    sign_in admin
    get admin_habitations_path(ownership: "all", corretor_id: broker.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(owned_by_broker.titulo_anuncio)
    expect(response.body).not_to include(owned_by_other.titulo_anuncio)
  end

  it "ordena 'Mais recentes' pela referência Salute numérica (maior código no topo)" do
    lower_salute_reference = create(
      :habitation,
      codigo: "8826",
      codigo_dwv: "488124",
      imovel_dwv: "Sim",
      titulo_anuncio: "Imóvel DWV com referência Salute menor"
    )
    higher_salute_reference = create(
      :habitation,
      codigo: "8882",
      codigo_dwv: "325054",
      imovel_dwv: "Sim",
      titulo_anuncio: "Imóvel DWV com referência Salute maior"
    )

    get admin_habitations_path(sort: "data_cadastro_crm", direction: "desc")

    expect(response).to have_http_status(:ok)
    expect(response.body.index(higher_salute_reference.titulo_anuncio)).to be < response.body.index(lower_salute_reference.titulo_anuncio)
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
      nome_empreendimento: "Edifício Concorde",
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
    expect(response.body).to include("Edifício Concorde")

    get admin_habitations_path(empreendimento_codigo: "Edificio concorde")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(standalone_unit.titulo_anuncio)
    expect(response.body).not_to include(other_property.titulo_anuncio)
  end

  it "usa a imagem original no card admin quando a miniatura da API vem recortada" do
    original_url = "https://dwvimagesv1.b-cdn.net/images/properties/demo/original.jpg"
    cropped_url = "#{original_url}?crop=200,300"
    habitation = create(
      :habitation,
      codigo: "IMG-CARD-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel com thumbnail recortado",
      pictures: [
        {
          "url" => original_url,
          "url_pequena" => cropped_url,
          "ordem" => 1
        }
      ]
    )

    get admin_habitations_path(referencia: habitation.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(src="#{original_url}"))
    expect(response.body).not_to include(%(src="#{cropped_url}"))
  end

  it "filtra empreendimento por corretor sem erro de distinct com ordenação" do
    broker = create(:admin_user, name: "Laudi Cardoso")
    create(:habitation, codigo: "183", tipo: "Empreendimento", nome_empreendimento: "Residencial 183")
    matching = create(
      :habitation,
      codigo: "EMP-BROKER-#{SecureRandom.hex(6)}",
      codigo_empreendimento: "183",
      titulo_anuncio: "Imóvel do corretor filtrado"
    )
    other_property = create(
      :habitation,
      codigo: "EMP-OTHER-#{SecureRandom.hex(6)}",
      codigo_empreendimento: "183",
      titulo_anuncio: "Imóvel de outro corretor"
    )
    matching.broker_assignments.create!(admin_user: broker, role: "captador")

    get admin_habitations_path(empreendimento_codigo: "183", corretor_id: broker.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching.titulo_anuncio)
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
    anchored_return_path = "#{return_path}#admin_habitation_#{habitation.id}"

    get return_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(CGI.escape(return_path))

    get edit_admin_habitation_path(habitation, return_to: anchored_return_path)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ERB::Util.html_escape(anchored_return_path))

    patch admin_habitation_path(habitation), params: {
      return_to: anchored_return_path,
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

    expect(response).to redirect_to(anchored_return_path)
  end

  it "remove filtros vazios do retorno para manter a URL do cadastro enxuta" do
    habitation = create(:habitation, codigo: "RET-LIMPO-#{SecureRandom.hex(6)}", titulo_anuncio: "Imóvel com retorno limpo")
    noisy_return_path = "/admin/habitations?ownership=all&q=#{CGI.escape(habitation.codigo)}&bairro=&status=&dorms%5B%5D=&vagas%5B%5D="
    clean_return_path = admin_habitations_path(ownership: "all", q: habitation.codigo)

    get noisy_return_path

    expect(response).to have_http_status(:ok)
    anchored_clean_return_path = "#{clean_return_path}#admin_habitation_#{habitation.id}"
    expect(response.body).to include(CGI.escapeHTML(edit_admin_habitation_path(habitation, return_to: anchored_clean_return_path)))
    expect(response.body).not_to include(CGI.escapeHTML(edit_admin_habitation_path(habitation, return_to: noisy_return_path)))

    get edit_admin_habitation_path(habitation, return_to: noisy_return_path)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ERB::Util.html_escape(clean_return_path))
    expect(response.body).not_to include(ERB::Util.html_escape(noisy_return_path))
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
    commercial_neighborhood_options = Nokogiri::HTML(response.body).css('select[name="bairro_comercial"] option').map(&:text)
    expect(commercial_neighborhood_options).not_to include("Praia Brava Balneário Camboriú")
  end

  it "marca cards inativos com classe visual cinza" do
    inactive = create(:habitation, codigo: "INATIVO-#{SecureRandom.hex(6)}", status: "Suspenso", titulo_anuncio: "Imóvel inativo")

    get admin_habitations_path(q: inactive.codigo, status: "Suspenso")

    expect(response).to have_http_status(:ok)
    card = Nokogiri::HTML(response.body).css(".property-card-horizontal").find { |node| node.text.include?(inactive.codigo) }
    expect(card["class"]).to include("property-card--inactive")
  end

  it "não marca imóvel ativo fora do site como card cinza" do
    internal = create(:habitation, codigo: "INTERNO-#{SecureRandom.hex(6)}", status: "Aluguel", exibir_no_site_flag: false, titulo_anuncio: "Imóvel interno ativo")

    get admin_habitations_path(q: internal.codigo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("FORA SITE")
    card = Nokogiri::HTML(response.body).css(".property-card-horizontal").find { |node| node.text.include?(internal.codigo) }
    expect(card["class"]).not_to include("property-card--inactive")
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
      complemento: "Casa 1",
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
        titulo_anuncio: "Casa em Condomínio completa pelo administrativo",
        exibir_no_site_flag: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      titulo_anuncio: "Casa em Condomínio completa pelo administrativo",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: admin.id
    )
    expect(intake.admin_reviewed_at).to be_present
  end

  it "bloqueia Salvar Interno e Devolver para captador sem título e sem descrição" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "INT-BLOCK-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review",
      titulo_anuncio: nil,
      descricao_web: nil
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      complemento: "Casa 1",
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
      save_internal_after_save: "1",
      habitation: { titulo_anuncio: "", descricao_web: "" }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Título do anúncio")
    expect(response.body).to include("Descrição do imóvel para Internet")
    expect(intake.reload.intake_status).to eq("submitted_for_admin_review")
  end

  it "bloqueia devolução administrativa de terreno em condomínio sem condomínio e lote" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "LAND-BLOCK-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review",
      categoria: "Terreno em Condomínio",
      nome_empreendimento: nil,
      complemento: nil,
      area_total_m2: 910,
      titulo_anuncio: "Terreno em Condomínio Porto Belo",
      descricao_web: "<div>Descrição completa do terreno em condomínio.</div>"
    )
    intake.create_address!(
      cep: "88210-000",
      logradouro: "Santos Dumont",
      numero: "0",
      complemento: "",
      bairro: "Porto Belo",
      cidade: "Porto Belo",
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
        titulo_anuncio: "Terreno em Condomínio Porto Belo"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Empreendimento")
    expect(response.body).to include("Complemento")
    expect(intake.reload.intake_status).to eq("submitted_for_admin_review")
  end

  it "permite Salvar Interno quando título e descrição estão preenchidos" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "INT-OK-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review"
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      complemento: "Casa 1",
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
      save_internal_after_save: "1",
      habitation: {
        titulo_anuncio: "Casa em Condomínio completa pelo administrativo",
        descricao_web: "<div>Descrição completa do imóvel para o site.</div>"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload.intake_status).to eq("internal")
  end

  it "permite Salvar Interno no administrativo sem foto e sem responder permuta" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "INT-NOPHOTO-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review",
      categoria: "Apartamento",
      tipo_vaga: "Privativa",
      numero_box: "10",
      bloco: "101",
      aceita_permuta_answer: nil,
      aceita_permuta_flag: false,
      pictures: [],
      photo_flow_choice: nil,
      photo_session_requested_at: nil
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      complemento: "Casa 1",
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
      save_internal_after_save: "1",
      habitation: {
        titulo_anuncio: "Apartamento completo pelo administrativo",
        descricao_web: "<div>Descrição completa do imóvel para o site.</div>"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload.intake_status).to eq("internal")
  end

  it "libera captação administrativa com proprietário antigo vinculado sem cidade cadastrada" do
    proprietor = create(:proprietor, city: nil, email: nil, phone_primary: "(47) 99601-2553")
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      proprietor: proprietor,
      codigo: "REL-OWNER-#{SecureRandom.hex(6)}",
      intake_status: "submitted_for_admin_review",
      proprietario: nil,
      proprietario_celular: nil,
      proprietario_email: nil,
      observacoes_visitas: "Dias/horários para visita: Seg, Manhã"
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Central",
      numero: "100",
      complemento: "Casa 1",
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
        titulo_anuncio: "Casa em Condomínio completa pelo administrativo"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      admin_reviewed_by_id: admin.id
    )
    expect(intake.intake_missing_requirements).not_to include("Dados do proprietário")
    expect(intake.intake_missing_requirements(require_owner_city: true)).not_to include("Dados do proprietário")
  end

  it "não remove autorização existente quando devolve para captador com campo de arquivo vazio" do
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "AUTH-KEEP-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Autorização",
      numero: "100",
      complemento: "Casa 1",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    intake.autorizacoes_venda.attach(
      io: StringIO.new("autorizacao existente"),
      filename: "autorizacao-existente.txt",
      content_type: "text/plain"
    )

    patch admin_habitation_path(intake), params: {
      release_to_broker_after_save: "1",
      habitation: {
        titulo_anuncio: "Casa em Condomínio com autorização preservada",
        autorizacoes_venda: [""]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(intake_status: "admin_approved")
    expect(intake.autorizacoes_venda).to be_attached
    expect(intake.autorizacoes_venda.attachments.map { |attachment| attachment.filename.to_s }).to include("autorizacao-existente.txt")
  end

  it "salva meio de garantia locatícia escalar ao devolver captação de aluguel para captador" do
    intake = create(
      :habitation,
      :broker_intake,
      admin_user: admin,
      codigo: "RENT-GUARANTEE-#{SecureRandom.hex(6)}",
      categoria: "Apartamento",
      nome_empreendimento: "Edifício Garantia",
      bloco: "702",
      tipo_vaga: "Privativa",
      numero_box: "20",
      status: "Aluguel",
      intake_modalidade: "locacao_anual",
      valor_venda_cents: 0,
      valor_locacao_cents: 8_000_00,
      salute_rental_management_answer: "sim",
      rental_guarantee_method: nil,
      intake_status: "submitted_for_admin_review"
    )
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Garantia",
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
        rental_guarantee_method: "Caução",
        titulo_anuncio: "Apartamento aluguel anual com garantia"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "admin_approved",
      rental_guarantee_method: "Caução",
      titulo_anuncio: "Apartamento aluguel anual com garantia"
    )
    expect(intake.intake_missing_requirements).not_to include("Meio de garantia locatícia")
  end

  it "salva autorização nova antes de validar devolução para captador" do
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "AUTH-NEW-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Autorização Nova",
      numero: "100",
      complemento: "Casa 1",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    authorization = Rack::Test::UploadedFile.new(
      StringIO.new("autorizacao nova"),
      "text/plain",
      original_filename: "autorizacao-nova.txt"
    )

    patch admin_habitation_path(intake), params: {
      release_to_broker_after_save: "1",
      habitation: {
        titulo_anuncio: "Casa em Condomínio com autorização nova",
        autorizacoes_venda: ["", authorization]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(intake_status: "admin_approved")
    expect(intake.autorizacoes_venda).to be_attached
    expect(intake.autorizacoes_venda.attachments.map { |attachment| attachment.filename.to_s }).to include("autorizacao-nova.txt")
  end

  it "salva captação revisada internamente sem exibir no site" do
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "INT-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.create_address!(
      cep: "88330-000",
      logradouro: "Rua Interna",
      numero: "200",
      complemento: "Casa 1",
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
    expect(response.body).to include("Devolver para captador")
    expect(response.body).to include("Salvar Interno")
    expect(response.body).to include("Salvar e sair")
    expect(response.body).to include("Autorizações de Venda")
    expect(response.body).to include("autorizacao.txt")
    expect(response.body).to include("Adicionar arquivos")

    patch admin_habitation_path(intake), params: {
      save_internal_after_save: "1",
      habitation: {
        titulo_anuncio: "Casa em Condomínio salva internamente",
        exibir_no_site_flag: "1"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(intake.reload).to have_attributes(
      intake_status: "internal",
      titulo_anuncio: "Casa em Condomínio salva internamente",
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
      complemento: "Casa 1",
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

    expect(response).to redirect_to(edit_admin_habitation_path(intake))
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
    page = Nokogiri::HTML(response.body)
    options = page.css('select[name="habitation[regiao_foco]"] option').map(&:text)
    expect(options).to include("Sim", "Não")
    expect(options).not_to include("Centro")
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

  it "adiciona novas fotos sem substituir fotos anexadas existentes" do
    habitation = create(:habitation, codigo: "FOTO-APPEND-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "104",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    habitation.photos.attach(
      io: StringIO.new("foto existente"),
      filename: "existente.jpg",
      content_type: "image/jpeg"
    )
    uploaded_photo = Tempfile.new(["nova-foto", ".jpg"])
    uploaded_photo.write("foto nova")
    uploaded_photo.rewind

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título com foto nova",
        photos: [Rack::Test::UploadedFile.new(uploaded_photo.path, "image/jpeg")]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.photos.attachments.size).to eq(2)
    expect(habitation.photos.attachments.map { |attachment| attachment.filename.to_s }).to include("existente.jpg")
  ensure
    uploaded_photo&.close
    uploaded_photo&.unlink
  end

  it "adiciona fotos enviadas por direct upload" do
    habitation = create(:habitation, codigo: "FOTO-DIRECT-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "106",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("foto enviada direto"),
      filename: "direct-upload.jpg",
      content_type: "image/jpeg"
    )

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título com direct upload",
        photos: [blob.signed_id]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.photos.attachments.size).to eq(1)
    expect(habitation.photos.attachments.first.blob).to eq(blob)
  end

  it "enfileira marca d'água das novas fotos fora da requisição" do
    clear_enqueued_jobs
    habitation = create(:habitation, codigo: "FOTO-WATERMARK-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "107",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    setting = PropertySetting.instance
    setting.watermark_image.attach(io: StringIO.new("watermark"), filename: "watermark.png", content_type: "image/png")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("foto enviada direto"),
      filename: "direct-watermark.jpg",
      content_type: "image/jpeg"
    )

    expect do
      patch admin_habitation_path(habitation), params: {
        habitation: {
          titulo_anuncio: "Título com direct upload",
          apply_photo_watermark: "1",
          photos: [blob.signed_id]
        }
      }
    end.to have_enqueued_job(HabitationPhotoWatermarkJob)

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload.photos.attachments.size).to eq(1)
  end

  it "mantém fotos da API ao adicionar fotos anexadas" do
    api_pictures = [
      { "url" => "https://example.com/api-um.jpg" },
      { "url" => "https://example.com/api-dois.jpg" }
    ]
    habitation = create(
      :habitation,
      codigo: "FOTO-API-KEEP-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Título antigo",
      pictures: api_pictures
    )
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "105",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    uploaded_photo = Tempfile.new(["foto-local", ".jpg"])
    uploaded_photo.write("foto local")
    uploaded_photo.rewind

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título com API preservada",
        photos: [Rack::Test::UploadedFile.new(uploaded_photo.path, "image/jpeg")]
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.pictures).to eq(api_pictures)
    expect(habitation.photos.attachments.size).to eq(1)
  ensure
    uploaded_photo&.close
    uploaded_photo&.unlink
  end

  it "exibe fotos da API junto com fotos anexadas na edição" do
    habitation = create(
      :habitation,
      codigo: "FOTO-MIX-#{SecureRandom.hex(6)}",
      pictures: [{ "url" => "https://example.com/api-visivel.jpg" }]
    )
    habitation.photos.attach(
      io: StringIO.new("foto local"),
      filename: "local.jpg",
      content_type: "image/jpeg"
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("local.jpg")
    expect(response.body).to include("https://example.com/api-visivel.jpg")
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

  it "salva fotos internas sem removê-las do cadastro" do
    habitation = create(
      :habitation,
      codigo: "FOTO-INTERNA-#{SecureRandom.hex(6)}",
      pictures: [
        { "url" => "https://example.com/api-site.jpg" },
        { "url" => "https://example.com/api-interna.jpg" }
      ]
    )
    habitation.create_address!(
      logradouro: "Rua Fotos",
      numero: "106",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    habitation.photos.attach(
      io: StringIO.new("foto site"),
      filename: "foto-site.jpg",
      content_type: "image/jpeg"
    )
    habitation.photos.attach(
      io: StringIO.new("foto interna"),
      filename: "foto-interna.jpg",
      content_type: "image/jpeg"
    )
    attachments = habitation.photos.attachments.order(:id).to_a

    patch admin_habitation_path(habitation), params: {
      habitation: {
        titulo_anuncio: "Título com fotos internas",
        site_hidden_photo_ids: attachments.second.id.to_s,
        site_hidden_picture_urls: "https://example.com/api-interna.jpg",
        photo_environment_assignments: {
          attachments.first.id.to_s => "Cozinha",
          attachments.second.id.to_s => "Fachada"
        }
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.photos.attachments.map(&:id)).to contain_exactly(*attachments.map(&:id))
    expect(habitation.photo_ids_order).to eq([attachments.second.id, attachments.first.id])
    expect(habitation.photo_environment_assignments).to eq(
      attachments.first.id.to_s => "Cozinha",
      attachments.second.id.to_s => "Fachada"
    )
    expect(habitation.site_hidden_photo_ids).to contain_exactly(attachments.second.id)
    expect(habitation.pictures.second["site_hidden"]).to eq(true)
    expect(habitation.public_image_sources.map { |source| source["url"] }).not_to include("https://example.com/api-interna.jpg")
    expect(habitation.public_image_sources.filter_map { |source| source["attachment"] }).not_to include(attachments.second)
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
    expect(response.body).to include('name="save_navigation_button"')
    expect(response.body).to include('value="stay"')
    expect(response.body).to include('value="exit"')
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

  it "prioriza o botão Salvar para permanecer na ficha mesmo com hidden divergente" do
    habitation = create(:habitation, codigo: "SAVE-BUTTON-#{SecureRandom.hex(6)}", titulo_anuncio: "Título antigo")
    habitation.create_address!(
      logradouro: "Rua Botão Salvar",
      numero: "123",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      save_navigation: "exit",
      save_navigation_button: "stay",
      habitation: {
        titulo_anuncio: "Título salvo pelo botão Salvar"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation))
    expect(habitation.reload.titulo_anuncio).to eq("Título salvo pelo botão Salvar")
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

  it "bloqueia seletores operacionais na edição do captador" do
    broker_profile = Profile.create!(
      name: "Corretor #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(:habitation, admin_user: broker, codigo: "LOCK-UI-#{SecureRandom.hex(6)}")

    sign_in broker
    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    %w[
      exibir_no_site_flag
      destaque_web_flag
      festival_salute_flag
      lancamento_flag
      tem_placa_flag
      exclusivo_flag
      imovel_dwv
    ].each do |field|
      input = html.at_css(%(input[type="checkbox"][name="habitation[#{field}]"]))
      expect(input).to be_present
      expect(input["disabled"]).to eq("disabled")
    end
  end

  it "ignora alteração manual dos seletores operacionais enviada por captador" do
    broker_profile = Profile.create!(
      name: "Corretor #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(
      :habitation,
      admin_user: broker,
      codigo: "LOCK-PARAMS-#{SecureRandom.hex(6)}",
      observacoes: "Observação inicial",
      exibir_no_site_flag: false,
      destaque_web_flag: false,
      festival_salute_flag: false,
      lancamento_flag: false,
      tem_placa_flag: false,
      exclusivo_flag: false,
      imovel_dwv: "Não"
    )
    habitation.create_address!(
      logradouro: "Rua Bloqueio",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    sign_in broker
    patch admin_habitation_path(habitation), params: {
      habitation: {
        observacoes: "Observação atualizada pelo captador",
        exibir_no_site_flag: "1",
        destaque_web_flag: "1",
        festival_salute_flag: "1",
        lancamento_flag: "1",
        tem_placa_flag: "1",
        exclusivo_flag: "1",
        imovel_dwv: "Sim"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    expect(habitation.reload).to have_attributes(
      observacoes: "Observação atualizada pelo captador",
      exibir_no_site_flag: false,
      destaque_web_flag: false,
      festival_salute_flag: false,
      lancamento_flag: false,
      tem_placa_flag: false,
      exclusivo_flag: false,
      imovel_dwv: "Não"
    )
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

  it "exibe anexos internos para perfil administrativo revisar autorização" do
    administrative_profile = Profile.create!(
      name: "Administrativo",
      active: true,
      permissions: Profile.default_permissions_for("Administrativo")
    )
    administrative_user = create(:admin_user, profile: administrative_profile)
    intake = create(:habitation, :broker_intake, admin_user: admin, codigo: "DOC-ADM-#{SecureRandom.hex(6)}", intake_status: "submitted_for_admin_review")
    intake.autorizacoes_venda.attach(
      io: StringIO.new("autorizacao"),
      filename: "autorizacao-administrativo.txt",
      content_type: "text/plain"
    )

    sign_in administrative_user
    get edit_admin_habitation_path(intake)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    documents_pane = page.at_css("#habitationTabsContent > #documents")

    expect(documents_pane).to be_present
    expect(documents_pane["role"]).to eq("tabpanel")
    expect(documents_pane["aria-labelledby"]).to eq("documents-tab")
    expect(response.body).to include("Autorizações de Venda")
    expect(response.body).to include("autorizacao-administrativo.txt")
    expect(response.body).to include("Adicionar arquivos")
  end

  it "anexa fichas de cadastro e autorizações pela aba de documentos" do
    habitation = create(:habitation, codigo: "DOC-UP-#{SecureRandom.hex(6)}")
    habitation.create_address!(
      logradouro: "Rua Upload Documento",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    ficha = Rack::Test::UploadedFile.new(
      StringIO.new("ficha de cadastro"),
      "text/plain",
      original_filename: "ficha-cadastro.txt"
    )
    autorizacao = Rack::Test::UploadedFile.new(
      StringIO.new("autorizacao de venda"),
      "text/plain",
      original_filename: "autorizacao-venda.txt"
    )

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      save_anchor: "documents",
      document_upload: "fichas_cadastro",
      habitation: {
        fichas_cadastro: [ficha]
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "documents"))
    expect(habitation.reload.fichas_cadastro.attachments.map { |attachment| attachment.filename.to_s }).to include("ficha-cadastro.txt")

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      save_anchor: "documents",
      document_upload: "autorizacoes_venda",
      habitation: {
        autorizacoes_venda: [autorizacao]
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "documents"))
    expect(habitation.reload.autorizacoes_venda.attachments.map { |attachment| attachment.filename.to_s }).to include("autorizacao-venda.txt")
  end

  it "abre cadastro de proprietário em modal no formulário do imóvel" do
    habitation = create(:habitation, codigo: "PROP-MODAL-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="quickProprietorModal"')
    expect(response.body).to include(quick_create_admin_proprietors_path)
    expect(response.body).to include("Salvar e selecionar")
    expect(response.body).not_to include("<iframe")
    expect(response.body).not_to include(new_admin_proprietor_path(embed: "modal"))
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

  it "envia para revisão administrativa quando corretor anexa fotos em captação sem fotos" do
    broker_profile = Profile.create!(
      name: "Corretor fotos #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(
      :habitation,
      :broker_intake,
      admin_user: broker,
      codigo: "PHOTO-REV-#{SecureRandom.hex(6)}",
      intake_status: "internal",
      pictures: [],
      exibir_no_site_flag: true,
      admin_reviewed_by: admin,
      admin_reviewed_at: 1.day.ago
    )
    file = Tempfile.new(["foto-revisao", ".jpg"])
    file.write("foto nova")
    file.rewind

    sign_in broker

    patch update_photos_admin_habitation_path(habitation), params: {
      habitation: {
        photos: [Rack::Test::UploadedFile.new(file.path, "image/jpeg")]
      }
    }

    expect(response).to redirect_to(admin_captacao_path(habitation))
    expect(habitation.reload).to have_attributes(
      intake_status: "submitted_for_admin_review",
      exibir_no_site_flag: false,
      admin_reviewed_by_id: nil,
      admin_reviewed_at: nil,
      broker_released_at: nil
    )
    expect(habitation.submitted_for_review_at).to be_present
    expect(habitation.photos).to be_attached
  ensure
    file&.close
    file&.unlink
  end

  it "não envia para revisão quando o campo de fotos vem vazio" do
    broker_profile = Profile.create!(
      name: "Corretor foto vazia #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(
      :habitation,
      :broker_intake,
      admin_user: broker,
      codigo: "PHOTO-BLANK-#{SecureRandom.hex(6)}",
      intake_status: "internal",
      pictures: [],
      exibir_no_site_flag: false
    )

    sign_in broker

    patch update_photos_admin_habitation_path(habitation), params: {
      habitation: {
        photos: [""]
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "media"))
    expect(habitation.reload).to have_attributes(intake_status: "internal")
    expect(habitation.photos).not_to be_attached
  end

  it "permite remover vínculo de empreendimento de um galpão no cadastro admin" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "DEV-#{SecureRandom.hex(4)}",
      nome_empreendimento: "Ville Del Acqua"
    )
    habitation = create(
      :habitation,
      codigo: "WH-#{SecureRandom.hex(4)}",
      categoria: "Galpão",
      codigo_empreendimento: development.codigo,
      nome_empreendimento: "Ville Del Acqua",
      use_development_photos_flag: true
    )
    habitation.create_address!(
      logradouro: "Rua Galpão #{SecureRandom.hex(4)}",
      numero: "8577",
      complemento: "Galpão 01",
      bairro: "Centro",
      cidade: "Camboriú",
      uf: "SC"
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    development_fields = page.css('[name="habitation[codigo_empreendimento]"]')
    expect(development_fields.any? { |field| field.name == "input" && field["type"] == "hidden" && field["value"].blank? }).to be(true)

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      habitation: {
        categoria: "Galpão",
        tipo: "Unitário",
        status: "Venda",
        codigo_empreendimento: "",
        nome_empreendimento: "Ville Del Acqua",
        use_development_photos_flag: "1"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, return_to: nil))
    expect(habitation.reload).to have_attributes(
      codigo_empreendimento: nil,
      nome_empreendimento: nil,
      use_development_photos_flag: false
    )
  end

  it "liga fotos do empreendimento por padrão quando vincula uma unidade pelo admin" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "DEV-FOTOS-#{SecureRandom.hex(4)}",
      nome_empreendimento: "Brava Garden"
    )
    habitation = create(
      :habitation,
      codigo: "UNIT-FOTOS-#{SecureRandom.hex(4)}",
      categoria: "Apartamento",
      codigo_empreendimento: nil,
      nome_empreendimento: nil,
      use_development_photos_flag: false
    )
    habitation.create_address!(
      logradouro: "Rua Unidade #{SecureRandom.hex(4)}",
      numero: "100",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      habitation: {
        categoria: "Apartamento",
        tipo: "Unitário",
        status: "Venda",
        codigo_empreendimento: development.codigo
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, return_to: nil))
    expect(habitation.reload).to have_attributes(
      codigo_empreendimento: development.codigo,
      use_development_photos_flag: true
    )
  end

  it "preserva fotos do empreendimento desligado quando o toggle é enviado no cadastro vinculado" do
    development = create(
      :habitation,
      tipo: "Empreendimento",
      categoria: "Empreendimento",
      codigo: "DEV-FOTOS-OFF-#{SecureRandom.hex(4)}",
      nome_empreendimento: "Brava Garden"
    )
    habitation = create(
      :habitation,
      codigo: "UNIT-FOTOS-OFF-#{SecureRandom.hex(4)}",
      categoria: "Apartamento",
      codigo_empreendimento: development.codigo,
      nome_empreendimento: "Brava Garden",
      use_development_photos_flag: true
    )
    habitation.create_address!(
      logradouro: "Rua Unidade #{SecureRandom.hex(4)}",
      numero: "101",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    patch admin_habitation_path(habitation), params: {
      save_navigation: "stay",
      habitation: {
        categoria: "Apartamento",
        tipo: "Unitário",
        status: "Venda",
        codigo_empreendimento: development.codigo,
        use_development_photos_flag: "0"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, return_to: nil))
    expect(habitation.reload.use_development_photos_flag).to be(false)
  end

  it "mostra resumo e fotos no detalhe sem expor cadastro interno para corretor não captador" do
    broker_profile = Profile.create!(
      name: "Corretor show restrito #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    captador = create(:admin_user, profile: broker_profile, name: "Captador Responsável")
    other_broker = create(:admin_user, profile: broker_profile, name: "Outro Corretor")
    habitation = create(
      :habitation,
      admin_user: captador,
      codigo: "SHOW-REST-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Apartamento completo para show",
      proprietario: "Proprietário Sigiloso",
      proprietario_celular: "(47) 99999-9999",
      nome_empreendimento: "Edifício Visível",
      area_privativa_m2: 123,
      caracteristicas: ["Sacada", "Cozinha planejada"],
      infra_estrutura: ["Piscina", "Academia"],
      tour_virtual: "https://example.com/tour",
      videos: ["https://example.com/video"],
      permuta_localizacao: "Balneário Camboriú",
      tipo_veiculo_aceito_permuta: "SUV",
      intake_origin: Habitation::INTAKE_ORIGIN_BROKER,
      intake_status: "internal",
      vista_referencia_externa: "VISTA-REF-1",
      praia_brava_flag: true,
      home_corporate_flag: true,
      pictures: [{ "url" => "https://example.com/foto-api-show.jpg" }]
    )
    habitation.create_address!(
      logradouro: "Rua Show",
      numero: "77",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    habitation.photos.attach(
      io: StringIO.new("foto local show"),
      filename: "foto-local-show.jpg",
      content_type: "image/jpeg"
    )
    habitation.fichas_cadastro.attach(
      io: StringIO.new("documento sigiloso"),
      filename: "ficha-sigilosa.txt",
      content_type: "text/plain"
    )
    habitation.broker_assignments.create!(
      admin_user: captador,
      role: "captador",
      commission_type: "percentage",
      commission_value: 4.5,
      observations: "Vínculo de captação"
    )

    sign_in other_broker
    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Apartamento completo para show")
    expect(response.body).to include("Edifício Visível")
    expect(response.body).to include("habitation-show-gallery-mosaic")
    expect(response.body).to include("Ver 2 fotos")
    expect(response.body).to include("https://example.com/foto-api-show.jpg")
    expect(response.body).to include("foto-local-show.jpg")
    expect(response.body).to include("data-fancybox")
    expect(response.body).to include("Informações principais")
    expect(response.body).to include("Captador")
    expect(response.body).to include("Captador Responsável")
    expect(response.body).to include("Valores")
    expect(response.body).to include("Endereço")
    expect(response.body).to include("Características")
    expect(response.body).to include("Características do imóvel")
    expect(response.body).to include("Cozinha planejada")
    expect(response.body).to include("Infraestrutura")
    expect(response.body).to include("Academia")
    expect(response.body).to include("Mídia complementar")
    expect(response.body).to include("Balneário Camboriú")
    expect(response.body).to include("https://example.com/tour")
    expect(response.body).to include("https://example.com/video")
    expect(response.body).not_to include("Responsáveis e vínculos")
    expect(response.body).not_to include("Captação e revisão")
    expect(response.body).not_to include("Integrações e códigos externos")
    expect(response.body).not_to include("Publicação, portais e SEO")
    expect(response.body).not_to include("Total aluguel")
    expect(response.body).not_to include("Aceita financiamento")
    expect(response.body).not_to include("Aceita permuta")
    expect(response.body).not_to include("VISTA-REF-1")
    expect(response.body).not_to include("SUV")
    expect(response.body).not_to include("Vínculo de captação")
    expect(response.body).not_to include("Proprietário Sigiloso")
    expect(response.body).not_to include("(47) 99999-9999")
    expect(response.body).not_to include("ficha-sigilosa.txt")
    expect(response.body).not_to include("Anexos e documentos internos")
  end

  it "oculta total aluguel no detalhe admin quando ele repete a locação" do
    habitation = create(
      :habitation,
      codigo: "TOTAL-IGUAL-#{SecureRandom.hex(6)}",
      status: "Aluguel",
      valor_venda_cents: 0,
      valor_locacao_cents: 6_900_00,
      valor_total_aluguel_cents: 6_900_00,
      valor_condominio_cents: 650_00,
      valor_iptu_cents: 150_00
    )

    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish
    expect(page_text).to include("Locação R$ 6.900,00")
    expect(page_text).to include("Condomínio R$ 650,00")
    expect(page_text).to include("IPTU R$ 150,00")
    expect(page_text).not_to include("Total aluguel")
  end

  it "exibe total aluguel no detalhe admin quando ele é maior que a locação" do
    habitation = create(
      :habitation,
      codigo: "TOTAL-MAIOR-#{SecureRandom.hex(6)}",
      status: "Aluguel",
      valor_venda_cents: 0,
      valor_locacao_cents: 6_900_00,
      valor_total_aluguel_cents: 7_700_00,
      valor_condominio_cents: 650_00,
      valor_iptu_cents: 150_00
    )

    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish
    expect(page_text).to include("Locação R$ 6.900,00")
    expect(page_text).to include("Total aluguel R$ 7.700,00")
  end

  it "mantém proprietário e anexos fora do detalhe simplificado para o captador do imóvel" do
    broker_profile = Profile.create!(
      name: "Corretor show captador #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    captador = create(:admin_user, profile: broker_profile, name: "Captador Show")
    habitation = create(
      :habitation,
      admin_user: captador,
      codigo: "SHOW-CAP-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel do captador",
      proprietario: "Proprietário do Captador",
      proprietario_email: "proprietario@example.com"
    )
    habitation.fichas_cadastro.attach(
      io: StringIO.new("documento"),
      filename: "ficha-captador.txt",
      content_type: "text/plain"
    )

    sign_in captador
    get admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Imóvel do captador")
    expect(response.body).to include("Editar cadastro")
    expect(response.body).not_to include("Proprietário do Captador")
    expect(response.body).not_to include("proprietario@example.com")
    expect(response.body).not_to include("Anexos e documentos internos")
    expect(response.body).not_to include("ficha-captador.txt")
  end

  it "bloqueia campos sensíveis para corretor ao editar imóvel atribuído" do
    broker_profile = Profile.create!(
      name: "Corretor edição limitada #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(
      :habitation,
      admin_user: broker,
      codigo: "LOCK-#{SecureRandom.hex(6)}",
      nome_empreendimento: "Empreendimento Original",
      titulo_anuncio: "Título Original",
      descricao_web: "Descrição Original",
      proprietario: "Proprietário Original",
      proprietario_email: "original@example.com",
      salute_rental_management_flag: false,
      salute_rental_management_answer: "nao",
      foto_classificacao: "Boas",
      valor_venda_cents: 500_000_00
    )
    habitation.create_address!(
      logradouro: "Rua Original",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )
    file = Tempfile.new(["ficha-bloqueada", ".txt"])
    file.write("ficha bloqueada")
    file.rewind

    sign_in broker
    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('input[name="habitation[titulo_anuncio]"]')["readonly"]).to eq("readonly")
    expect(page.at_css('input[name="habitation[nome_empreendimento]"]')["readonly"]).to eq("readonly")
    expect(page.at_css('input[name="habitation[proprietario]"]')["readonly"]).to eq("readonly")
    expect(page.at_css('input[name="habitation[address_attributes][logradouro]"]')["readonly"]).to eq("readonly")
    expect(page.at_css('input[type="checkbox"][name="habitation[salute_rental_management_flag]"]')["disabled"]).to eq("disabled")
    expect(page.at_css('select[name="habitation[salute_rental_management_answer]"]')["disabled"]).to eq("disabled")
    photo_classification_select = page.at_css('select[name="habitation[foto_classificacao]"]')
    expect(photo_classification_select["disabled"]).to eq("disabled") if photo_classification_select
    expect(response.body).not_to include("Adicionar arquivos")

    patch admin_habitation_path(habitation), params: {
      habitation: {
        status: "Aluguel",
        categoria: "Apartamento",
        dormitorios_qtd: "3",
        caracteristicas: ["Mobiliado", "Vista mar"],
        valor_venda_formatted: "600.000,00",
        nome_empreendimento: "Empreendimento Alterado",
        titulo_anuncio: "Título Alterado",
        descricao_web: "Descrição Alterada",
        proprietario: "Proprietário Alterado",
        proprietario_email: "alterado@example.com",
        salute_rental_management_flag: "1",
        salute_rental_management_answer: "sim",
        foto_classificacao: "Profissionais",
        fichas_cadastro: [Rack::Test::UploadedFile.new(file.path, "text/plain")],
        address_attributes: {
          id: habitation.address.id,
          logradouro: "Rua Alterada",
          numero: "99",
          bairro: "Outro Bairro",
          cidade: "Itajaí",
          uf: "SC"
        }
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation).to have_attributes(
      status: "Aluguel",
      categoria: "Apartamento",
      dormitorios_qtd: 3,
      valor_venda_cents: 600_000_00,
      nome_empreendimento: "Empreendimento Original",
      titulo_anuncio: "Título Original",
      proprietario: "Proprietário Original",
      # E-mail do proprietário liberado para o corretor (demais dados seguem travados).
      proprietario_email: "alterado@example.com",
      salute_rental_management_flag: false,
      salute_rental_management_answer: "nao",
      foto_classificacao: "Boas"
    )
    expect(habitation.caracteristicas).to include("Mobiliado", "Vista mar")
    expect(habitation.display_description).to include("Descrição Original")
    expect(habitation.display_description).not_to include("Descrição Alterada")
    expect(habitation.address.reload).to have_attributes(
      logradouro: "Rua Original",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú"
    )
    expect(habitation.fichas_cadastro).not_to be_attached

    patch update_photos_admin_habitation_path(habitation), params: {
      habitation: {
        foto_classificacao: "Profissionais"
      }
    }

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "media"))
    expect(habitation.reload.foto_classificacao).to eq("Boas")
  ensure
    file&.close
    file&.unlink
  end

  it "bloqueia título e descrição para usuário não administrativo mesmo com acesso amplo a imóveis" do
    wide_profile = Profile.create!(
      name: "Corretor amplo #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor").deep_merge(
        "imoveis" => { "view" => true, "manage" => true, "scope" => "all" }
      )
    )
    broker = create(:admin_user, profile: wide_profile)
    habitation = create(
      :habitation,
      admin_user: broker,
      codigo: "CONTENT-LOCK-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Título Original",
      descricao_web: "Descrição Original",
      valor_venda_cents: 500_000_00
    )
    habitation.create_address!(
      logradouro: "Rua Conteúdo",
      numero: "10",
      bairro: "Centro",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    sign_in broker
    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('input[name="habitation[titulo_anuncio]"]')["readonly"]).to eq("readonly")

    patch admin_habitation_path(habitation), params: {
      habitation: {
        valor_venda_formatted: "600.000,00",
        titulo_anuncio: "Título Alterado",
        descricao_web: "Descrição Alterada"
      }
    }

    expect(response).to redirect_to(admin_habitations_path)
    habitation.reload
    expect(habitation.valor_venda_cents).to eq(600_000_00)
    expect(habitation.titulo_anuncio).to eq("Título Original")
    expect(habitation.display_description).to include("Descrição Original")
    expect(habitation.display_description).not_to include("Descrição Alterada")
  end

  it "mostra ações de IA de título e descrição para administrador e Administrativo" do
    habitation = create(:habitation, codigo: "AI-ADMIN-#{SecureRandom.hex(6)}")

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("IA para título e descrição")
    expect(response.body).to include("Gerar prévia")
    page = Nokogiri::HTML(response.body)
    generate_ai_link = page.at_css(%(a[href="#{generate_ai_preview_admin_habitation_path(habitation)}"]))
    expect(generate_ai_link["data-turbo"]).to eq("true")
    expect(generate_ai_link["data-turbo-method"]).to eq("post")

    administrative_profile = Profile.create!(
      name: "Administrativo",
      permissions: Profile.default_permissions_for("Administrativo")
    )
    administrativo = create(:admin_user, profile: administrative_profile, role: :editor)

    sign_in administrativo
    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("IA para título e descrição")
    expect(response.body).to include("Gerar prévia")
  end

  it "oculta e bloqueia ações de IA de título e descrição para corretor" do
    broker_profile = Profile.create!(
      name: "Corretor IA #{SecureRandom.hex(6)}",
      permissions: Profile.default_permissions_for("Corretor")
    )
    broker = create(:admin_user, profile: broker_profile)
    habitation = create(:habitation, admin_user: broker, codigo: "AI-BLOCK-#{SecureRandom.hex(6)}")

    sign_in broker

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("IA para título e descrição")
    expect(response.body).not_to include("Gerar prévia")
    expect(response.body).not_to include(generate_ai_preview_admin_habitation_path(habitation))

    post generate_ai_preview_admin_habitation_path(habitation)
    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "features"))
    expect(flash[:alert]).to eq("Apenas administradores ou usuários do Administrativo podem gerar, formatar ou aplicar sugestões de IA.")

    patch format_ai_suggestion_admin_habitation_path(habitation, suggestion_id: 999)
    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "features"))

    patch apply_ai_suggestion_admin_habitation_path(habitation, suggestion_id: 999)
    expect(response).to redirect_to(edit_admin_habitation_path(habitation, anchor: "features"))
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

  it "não exibe bloco de documentos do Vista para imóvel de ficha interna sem integração" do
    habitation = create(
      :habitation,
      :broker_intake,
      codigo: "FICHA-SEM-VISTA-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Ficha concluída internamente",
      intake_status: "internal",
      vista_import_batch_id: nil,
      vista_codigo: nil,
      vista_imo_codigo: nil,
      vista_referencia_externa: nil,
      status_vista: nil
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Documentos do Vista")
    expect(response.body).not_to include("Nenhum documento do Vista vinculado a este imóvel")
  end

  it "não exibe bloco vazio de documentos do Vista quando não há arquivo vinculado" do
    habitation = create(
      :habitation,
      codigo: "VISTA-SEM-DOC-#{SecureRandom.hex(6)}",
      titulo_anuncio: "Imóvel com referência Vista sem documento",
      status_vista: "Verificar"
    )

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Documentos do Vista")
    expect(response.body).not_to include("Nenhum documento do Vista vinculado a este imóvel")
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
    return_path = admin_habitations_path(ownership: "all", q: habitation.codigo)
    expect {
      delete "/admin/habitations/#{habitation.id}/purge_attachment/autorizacoes_venda/#{attachment.id}", params: { return_to: return_path }
    }.to change(HabitationAuditLog, :count).by(1)

    expect(response).to redirect_to(edit_admin_habitation_path(habitation, return_to: return_path, anchor: "documents"))
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
    expect(broker_log.change_summaries.any? { |summary| summary[:after].to_s.include?("Corretor Auditor") }).to be(true)

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

  it "permite casa em condomínio no mesmo endereço com complemento diferente" do
    existing = create(:habitation, codigo: "COND-#{SecureRandom.hex(6)}", categoria: "Casa em Condomínio", bloco: "")
    existing.create_address!(
      logradouro: "Rua Higino João Pio",
      numero: "420",
      complemento: "01",
      bairro: "Praia do Estaleirinho",
      cidade: "Balneário Camboriú",
      uf: "SC"
    )

    expect {
      post admin_habitations_path, params: {
        habitation: {
          categoria: "Casa em Condomínio",
          status: "Venda",
          tipo: "Unitário",
          bloco: "",
          address_attributes: {
            logradouro: "Rua Higino João Pio",
            numero: "420",
            complemento: "02",
            bairro: "Praia do Estaleirinho",
            cidade: "Balneário Camboriú",
            uf: "SC"
          }
        }
      }
    }.to change(Habitation, :count).by(1)

    created_habitation = Habitation.order(:id).last
    expect(response).to redirect_to(edit_admin_habitation_path(created_habitation))
  end

  it "permite terreno no mesmo endereço com complemento diferente" do
    existing = create(:habitation, codigo: "LAND-#{SecureRandom.hex(6)}", categoria: "Terreno", status: "Venda", bloco: "")
    existing.create_address!(
      logradouro: "Ivo José Rebello",
      numero: "110",
      complemento: "802",
      bairro: "Condomínio Caledônia",
      cidade: "Camboriú",
      uf: "SC"
    )

    expect {
      post admin_habitations_path, params: {
        habitation: {
          categoria: "Terreno",
          status: "Venda",
          tipo: "Unitário",
          bloco: "",
          nome_empreendimento: "Caledônia Private Village",
          address_attributes: {
            logradouro: "Ivo José Rebello",
            numero: "110",
            complemento: "303",
            bairro: "Condomínio Caledônia",
            cidade: "Camboriú",
            uf: "SC"
          }
        }
      }
    }.to change(Habitation, :count).by(1)

    created = Habitation.order(:created_at).last
    expect(response).to redirect_to(edit_admin_habitation_path(created))
  end

  it "bloqueia terreno no mesmo endereço quando complemento e bloco são iguais" do
    existing = create(:habitation, codigo: "LAND-DUP-#{SecureRandom.hex(6)}", categoria: "Terreno", status: "Venda", bloco: "Quadra B")
    existing.create_address!(
      logradouro: "Ivo José Rebello",
      numero: "110",
      complemento: "303",
      bairro: "Condomínio Caledônia",
      cidade: "Camboriú",
      uf: "SC"
    )

    expect {
      post admin_habitations_path, params: {
        habitation: {
          categoria: "Terreno",
          status: "Venda",
          tipo: "Unitário",
          bloco: "Quadra B",
          nome_empreendimento: "Caledônia Private Village",
          address_attributes: {
            logradouro: "Ivo José Rebello",
            numero: "110",
            complemento: "303",
            bairro: "Condomínio Caledônia",
            cidade: "Camboriú",
            uf: "SC"
          }
        }
      }
    }.not_to change(Habitation, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("rua, número, complemento, bloco e status comercial")
    expect(response.body).to include(existing.codigo)
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
      unit: "apto 1203",
      status: "Venda"
    }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload.fetch("complete")).to eq(true)
    expect(payload.fetch("duplicate")).to eq(true)
    expect(payload.fetch("matches").first.fetch("codigo")).to eq(existing.codigo)
  end

  it "não retorna duplicidade em tempo real para terreno com complemento diferente" do
    existing = create(:habitation, codigo: "CHK-LAND-#{SecureRandom.hex(6)}", categoria: "Terreno", status: "Venda")
    existing.create_address!(
      logradouro: "Ivo José Rebello",
      numero: "110",
      complemento: "802",
      bairro: "Condomínio Caledônia",
      cidade: "Camboriú",
      uf: "SC"
    )

    get check_admin_habitation_duplicate_path, params: {
      street: "Ivo Jose Rebello",
      number: "110",
      building: "Caledônia Private Village",
      unit: "",
      complement: "303",
      category: "Terreno",
      status: "Venda"
    }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload.fetch("complete")).to eq(true)
    expect(payload.fetch("duplicate")).to eq(false)
    expect(payload.fetch("comparison")).to eq("condominium_unit")
  end

  it "não retorna duplicidade em tempo real quando status comercial é diferente" do
    existing = create(:habitation, codigo: "CHK-STATUS-#{SecureRandom.hex(6)}", status: "Venda", nome_empreendimento: "Edifício Aurora", bloco: "1203")
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
      unit: "apto 1203",
      status: "Aluguel"
    }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload.fetch("complete")).to eq(true)
    expect(payload.fetch("duplicate")).to eq(false)
    expect(payload.fetch("matches")).to be_empty
  end

  it "registra contato com o proprietário: zera o relógio e grava na timeline" do
    habitation = create(:habitation, codigo: "OWNER-CONTACT-#{SecureRandom.hex(4)}", data_atualizacao_crm: 30.days.ago)

    expect {
      post register_owner_contact_admin_habitation_path(habitation)
    }.to change {
      HabitationAuditLog.where(habitation_id: habitation.id, action: "owner_contact_no_change").count
    }.by(1)

    expect(response).to redirect_to(edit_admin_habitation_path(habitation))
    expect(habitation.reload.data_atualizacao_crm).to be > 1.minute.ago
  end

  it "filtra imóveis por múltiplas cidades (multiseleção)" do
    h_itajai = create(:habitation, codigo: "MC-ITJ-#{SecureRandom.hex(4)}", status: "Venda", titulo_anuncio: "Imovel Itajai MultiCidade")
    h_itajai.create_address!(logradouro: "Rua A", numero: "1", bairro: "Centro", cidade: "Itajaí", uf: "SC")
    h_bc = create(:habitation, codigo: "MC-BC-#{SecureRandom.hex(4)}", status: "Venda", titulo_anuncio: "Imovel BC MultiCidade")
    h_bc.create_address!(logradouro: "Rua B", numero: "2", bairro: "Centro", cidade: "Balneário Camboriú", uf: "SC")
    h_other = create(:habitation, codigo: "MC-OTHER-#{SecureRandom.hex(4)}", status: "Venda", titulo_anuncio: "Imovel Outro MultiCidade")
    h_other.create_address!(logradouro: "Rua C", numero: "3", bairro: "Centro", cidade: "Florianópolis", uf: "SC")

    get admin_habitations_path(cidade: ["Itajaí", "Balneário Camboriú"])

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Imovel Itajai MultiCidade")
    expect(response.body).to include("Imovel BC MultiCidade")
    expect(response.body).not_to include("Imovel Outro MultiCidade")
  end
end

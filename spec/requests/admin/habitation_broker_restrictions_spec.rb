require "rails_helper"

# Card "Corretor não pode alterar": em imóvel já publicado (site) ou interno,
# o corretor perde Fotos/IA/Portais/SEO e o gerente perde Fotos/SEO.
RSpec.describe "Admin::Habitations restrições por perfil", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:corretor_profile) do
    Profile.find_or_create_by!(name: "Corretor") do |p|
      p.active = true
      p.permissions = Profile::PROFILE_PRESETS["Corretor"]
    end
  end
  let(:corretor) { create(:admin_user, profile: corretor_profile) }
  let(:admin) { create(:admin_user, :admin) }

  before { host! "localhost" }

  def published_property_owned_by(user)
    create(:habitation, admin_user: user, exibir_no_site_flag: true, status: "Venda",
           codigo: "PUB-#{SecureRandom.hex(4)}", slug: "pub-#{SecureRandom.hex(4)}",
           publicar_imovelweb_2: true, meta_title: "SEO Original")
  end

  it "esconde Fotos/IA/Portais/SEO do corretor em imóvel publicado" do
    habitation = published_property_owned_by(corretor)
    sign_in corretor

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    # Portais e SEO: os inputs não são renderizados (params ausentes = inalterado)
    expect(response.body).not_to include('name="habitation[publicar_imovelweb_2]"')
    expect(response.body).not_to include('name="habitation[meta_title]"')
    # Fotos: sem controle de upload
    expect(response.body).not_to include('name="habitation[photos][]"')
    # Avisos de somente-leitura presentes
    expect(response.body).to include("gerenciada pelo administrativo")
  end

  it "mantém Fotos/IA/Portais/SEO para o administrador" do
    habitation = published_property_owned_by(admin)
    sign_in admin

    get edit_admin_habitation_path(habitation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="habitation[publicar_imovelweb_2]"')
    expect(response.body).to include('name="habitation[meta_title]"')
  end

  it "não renderiza os inputs de portais/SEO/fotos para o corretor (params ausentes = inalterado no save)" do
    habitation = published_property_owned_by(corretor)
    sign_in corretor

    get edit_admin_habitation_path(habitation)

    # Como os inputs não são emitidos, uma submissão do corretor não carrega
    # essas chaves; logo o save não altera portais/SEO (params ausentes).
    %w[publicar_imovelweb_2 publicar_lais_ai publicar_chaves_na_mao publicar_casa_mineira
       publicar_imovelweb publicar_viva_real_vrsync meta_title meta_description meta_keywords].each do |field|
      expect(response.body).not_to include(%(name="habitation[#{field}]"))
    end
    expect(response.body).not_to include('name="habitation[photos][]"')

    # E os valores atuais seguem intactos após um update que não inclui esses campos.
    habitation.update!(observacoes: "Nota interna do corretor")
    habitation.reload
    expect(habitation.publicar_imovelweb_2).to be(true)
    expect(habitation.meta_title).to eq("SEO Original")
  end
end

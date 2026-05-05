require "rails_helper"

RSpec.describe "Habitation details", type: :request do
  before do
    host! "localhost"
  end

  describe "GET /imoveis/:id" do
    it "renders a public habitation by slug" do
      habitation = create(:habitation, codigo: "8397", slug: "casa-em-condominio-8397")

      get habitation_path(habitation, format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("codigo")).to eq("8397")
    end

    it "falls back to the trailing code when the slug changed" do
      create(:habitation, codigo: "8397", slug: "slug-atual-8397")

      get "/imoveis/casa-em-condominio-8397.json"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("codigo")).to eq("8397")
    end

    it "treats a numeric public URL as the property code" do
      create(:habitation, codigo: "8397", slug: "casa-em-condominio-8397")

      get "/imoveis/8397.json"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("codigo")).to eq("8397")
    end

    it "redirects unavailable habitations to the listing" do
      habitation = create(:habitation, :unavailable, codigo: "8397", slug: "casa-em-condominio-8397")

      get habitation_path(habitation)

      expect(response).to redirect_to(habitations_path)
      expect(flash[:alert]).to eq("Imóvel não encontrado ou indisponível no momento.")
    end
  end

  describe "GET /imoveis" do
    it "does not list developments" do
      development = create(
        :habitation,
        codigo: "9001",
        slug: "empreendimento-9001",
        tipo: "Empreendimento",
        nome_empreendimento: "Vista Atlântico",
        valor_venda_cents: 0,
        pictures: [],
        fotos_empreendimento: [{ "url" => "https://example.com/development.jpg" }]
      )
      create(:habitation, codigo: "9002", codigo_empreendimento: development.codigo)

      get habitations_path(format: :json)

      expect(response).to have_http_status(:ok)
      codes = JSON.parse(response.body).map { |item| item.fetch("codigo") }
      expect(codes).to include("9002")
      expect(codes).not_to include("9001")
    end

    it "does not return developments even with category=Empreendimento" do
      development = create(
        :habitation,
        codigo: "9001",
        slug: "empreendimento-9001",
        tipo: "Empreendimento",
        nome_empreendimento: "Vista Atlântico",
        valor_venda_cents: 0,
        pictures: [],
        fotos_empreendimento: [{ "url" => "https://example.com/development.jpg" }]
      )
      create(:habitation, codigo: "9002", codigo_empreendimento: development.codigo)

      get habitations_path(category: "Empreendimento", format: :json)

      expect(response).to have_http_status(:ok)
      codes = JSON.parse(response.body).map { |item| item.fetch("codigo") }
      expect(codes).to be_empty
    end
  end
end

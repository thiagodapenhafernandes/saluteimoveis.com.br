require "rails_helper"

RSpec.describe "Admin::Leads", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, :admin) }

  before do
    host! "localhost"
    sign_in admin
  end

  describe "GET /admin/leads" do
    it "exibe o kanban como visualizacao padrao" do
      create(:lead, name: "Cliente Kanban", phone: "11999999999", status: "Novo")
      create(:lead, name: "Cliente Atendimento", phone: "11888888888", status: "Em Atendimento")

      get admin_leads_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lead-kanban")
      expect(response.body).to include("Cliente Kanban")
      expect(response.body).to include("Em Atendimento")
    end

    it "mantem a visualizacao em lista como alternativa" do
      create(:lead, name: "Cliente Lista", phone: "11999999999", status: "Novo")

      get admin_leads_path(view: "list")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<table")
      expect(response.body).to include("Cliente Lista")
    end
  end

  describe "PATCH /admin/leads/:id" do
    it "atualiza status dinamico via json" do
      lead = create(:lead, status: "Novo")

      patch admin_lead_path(lead),
            params: { lead: { status: "Em Atendimento" } },
            headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(lead.reload.status).to eq("Em Atendimento")
      expect(JSON.parse(response.body)).to include("status" => "Em Atendimento")
    end
  end
end

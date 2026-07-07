require "rails_helper"

RSpec.describe Dwv::SyncRunnerService do
  describe "#call" do
    it "destroys only DWV habitations returned as removed" do
      removed_dwv = create(:habitation, codigo_dwv: "removed-dwv", imovel_dwv: "Sim")
      local_with_same_external_code = create(:habitation, codigo_dwv: "local-code", imovel_dwv: "Não")
      active_dwv = create(:habitation, codigo_dwv: "active-dwv", imovel_dwv: "Sim")
      client = instance_double(Dwv::Client)
      service = described_class.new

      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      allow(service).to receive(:build_client).and_return(client)
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: true, last_updates: nil).and_return(
        "data" => [
          { "id" => "removed-dwv" },
          { "id" => "local-code" }
        ]
      )

      result = service.call(mode: "deactivate_removed", limit: 50, max_pages: 1)

      expect(result[:deleted]).to eq(1)
      expect(Habitation.exists?(removed_dwv.id)).to eq(false)
      expect(Habitation.exists?(local_with_same_external_code.id)).to eq(true)
      expect(Habitation.exists?(active_dwv.id)).to eq(true)
    end

    it "imports recently updated properties and destroys removed ones in incremental mode" do
      removed_dwv = create(:habitation, codigo_dwv: "removed-dwv", imovel_dwv: "Sim")
      untouched_dwv = create(:habitation, codigo_dwv: "untouched-dwv", imovel_dwv: "Sim")
      client = instance_double(Dwv::Client)
      service = described_class.new

      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      allow(service).to receive(:build_client).and_return(client)
      allow(service).to receive(:pause_if_needed)

      window = [1.day.ago.to_date, Date.current].map { |date| date.strftime("%d/%m/%Y") }.join(",")
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: nil, last_updates: window).and_return(
        "data" => [{ "id" => "updated-dwv" }]
      )
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: true, last_updates: window).and_return(
        "data" => [{ "id" => "removed-dwv" }]
      )
      allow(client).to receive(:property_details).with("updated-dwv").and_return({ "id" => "updated-dwv" })
      import_service = instance_double(Dwv::PropertyImportService)
      allow(Dwv::PropertyImportService).to receive(:new).with({ "id" => "updated-dwv" }).and_return(import_service)
      allow(import_service).to receive(:perform).and_return({ success: true })

      result = service.call(mode: "incremental", limit: 50, max_pages: 1)

      expect(result[:imported]).to eq(1)
      expect(result[:deleted]).to eq(1)
      expect(result[:errors_count]).to eq(0)
      expect(Habitation.exists?(removed_dwv.id)).to eq(false)
      expect(Habitation.exists?(untouched_dwv.id)).to eq(true)
    end

    it "counts errors without aborting the incremental run" do
      client = instance_double(Dwv::Client)
      service = described_class.new

      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      allow(service).to receive(:build_client).and_return(client)
      allow(service).to receive(:pause_if_needed)

      window = [1.day.ago.to_date, Date.current].map { |date| date.strftime("%d/%m/%Y") }.join(",")
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: nil, last_updates: window).and_return(
        "data" => [{ "id" => "broken-dwv" }, { "id" => "ok-dwv" }]
      )
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: true, last_updates: window).and_return("data" => [])
      allow(client).to receive(:property_details).with("broken-dwv").and_raise(Dwv::Client::RequestError, "Erro DWV (HTTP 500): boom")
      allow(client).to receive(:property_details).with("ok-dwv").and_return({ "id" => "ok-dwv" })
      import_service = instance_double(Dwv::PropertyImportService, perform: { success: true })
      allow(Dwv::PropertyImportService).to receive(:new).with({ "id" => "ok-dwv" }).and_return(import_service)

      result = service.call(mode: "incremental", limit: 50, max_pages: 1)

      expect(result[:imported]).to eq(1)
      expect(result[:errors_count]).to eq(1)
      expect(result[:errors_by_reason].keys.first).to include("HTTP 500")
    end
  end
end

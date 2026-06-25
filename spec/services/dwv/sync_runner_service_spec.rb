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
      allow(client).to receive(:list_properties).with(limit: 50, page: 1, deleted: true).and_return(
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
  end
end

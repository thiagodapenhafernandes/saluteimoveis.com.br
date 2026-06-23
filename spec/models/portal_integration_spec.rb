require "rails_helper"

RSpec.describe PortalIntegration, type: :model do
  describe "#feed_strategy" do
    it "uses OpenNavent only for the first Imovelweb account" do
      expect(described_class.new(portal: "imovelweb").feed_strategy).to eq("open_navent_xml")
      expect(described_class.new(portal: "imovelweb_2").feed_strategy).to eq("olx_xml")
    end
  end

  describe "#requires_account_id?" do
    it "requires account configuration for OpenNavent feeds" do
      expect(described_class.new(portal: "imovelweb")).to be_requires_account_id
    end
  end
end

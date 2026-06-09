require "rails_helper"

RSpec.describe PropertySetting, type: :model do
  describe ".instance" do
    it "creates a singleton with the default watermark position" do
      setting = described_class.instance

      expect(setting).to be_persisted
      expect(setting.watermark_position).to eq("bottom_left")
    end
  end

  it "validates predefined watermark positions" do
    setting = described_class.new(watermark_position: "top_left")

    expect(setting).not_to be_valid
    expect(setting.errors[:watermark_position]).to be_present
  end
end

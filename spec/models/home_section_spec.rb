require "rails_helper"

RSpec.describe HomeSection, type: :model do
  describe "publication filter compatibility" do
    it "maps the legacy Exibir no Site Salute filter to Exibir no site" do
      section = described_class.new(
        section_type: "featured_properties",
        title: "Destaques",
        property_filters: { "exibir_site_salute" => "1" }
      )

      expect(section.property_filter_enabled?("exibir_no_site")).to be(true)
      expect(section.apply_property_filters(Habitation.all).to_sql).to include("\"habitations\".\"exibir_no_site_flag\" = TRUE")
    end

    it "normalizes the legacy filter key to the canonical Exibir no site key" do
      section = described_class.new(
        section_type: "featured_properties",
        title: "Destaques",
        property_filters: { "exibir_site_salute" => "1" }
      )

      section.valid?

      expect(section.property_filters).to eq("exibir_no_site" => "1")
    end
  end
end

require "rails_helper"

RSpec.describe HabitationsHelper, type: :helper do
  describe "#formatted_habitation_description" do
    it "does not add spaces inside decimal area values" do
      description = "<div>Excelente galpão com 4500m² de área privativa e 10000.2m² de área total.Localizado no Tabuleiro.</div>"

      formatted = helper.formatted_habitation_description(description)

      expect(formatted).to include("10000.2m²")
      expect(formatted).not_to include("10000. 2m²")
    end

    it "keeps decimal values intact when long html descriptions are paragraphized" do
      repeated_text = "Área total 10000.2m². Localização estratégica. Operação logística pronta. " * 15
      description = "<div>#{repeated_text}</div>"

      formatted = helper.formatted_habitation_description(description)

      expect(formatted).to include("10000.2m²")
      expect(formatted).not_to include("10000. 2m²")
    end
  end
end

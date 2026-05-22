require "rails_helper"

RSpec.describe Habitation, type: :model do
  describe "#public_image_sources" do
    let(:vista_picture) do
      {
        "url" => "https://cdn.vistahost.com.br/saluteim20174/vista.imobi/fotos/123/foto.jpg",
        "principal" => true
      }
    end

    it "prioriza fotos anexadas na base para imóveis vindos do Vista" do
      habitation = create(:habitation, pictures: [vista_picture], imovel_dwv: "Nao")
      habitation.photos.attach(
        io: StringIO.new("imagem"),
        filename: "foto.jpg",
        content_type: "image/jpeg"
      )

      first_source = habitation.public_image_sources.first

      expect(first_source["attachment"]).to be_present
      expect(first_source["url"]).to include("/rails/active_storage/")
      expect(first_source["url"]).not_to include("vistahost.com.br")
    end

    it "mantem URLs JSON como prioridade para imóveis DWV" do
      habitation = create(:habitation, pictures: [vista_picture], imovel_dwv: "Sim")
      habitation.photos.attach(
        io: StringIO.new("imagem"),
        filename: "foto.jpg",
        content_type: "image/jpeg"
      )

      first_source = habitation.public_image_sources.first

      expect(first_source["url"]).to eq(vista_picture["url"])
    end
  end
end

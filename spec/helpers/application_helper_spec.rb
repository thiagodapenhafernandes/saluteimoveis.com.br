require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#whatsapp_conversion_tracking" do
    it "maps sale and rent negotiation types to external conversion events" do
      expect(helper.whatsapp_conversion_tracking("sale")).to include(
        business_type: "venda",
        conversion_event: "ctwa_venda",
        ctwa_id: "id-ctwa.venda"
      )
      expect(helper.whatsapp_conversion_tracking("rent")).to include(
        business_type: "aluguel",
        conversion_event: "ctwa_aluguel",
        ctwa_id: "id-ctwa.aluguel"
      )
    end

    it "uses the current listing context to split sale_rent properties when possible" do
      expect(helper.whatsapp_conversion_tracking("sale_rent", transaction_type: "aluguel")).to include(
        business_type: "aluguel",
        conversion_event: "ctwa_aluguel"
      )
      expect(helper.whatsapp_conversion_tracking("sale_rent", transaction_type: "venda")).to include(
        business_type: "venda",
        conversion_event: "ctwa_venda"
      )
    end

    it "keeps a distinct event for sale_rent when no context is available" do
      expect(helper.whatsapp_conversion_tracking("sale_rent")).to include(
        business_type: "venda_aluguel",
        conversion_event: "ctwa_venda_aluguel",
        ctwa_id: "id-ctwa.venda_aluguel"
      )
    end
  end

  describe "#public_image_url" do
    it "remove host absoluto e troca redirect por proxy em URLs internas do Active Storage" do
      url = "https://143.110.138.67/rails/active_storage/blobs/redirect/signed/file.jpg"

      expect(helper.public_image_url(url)).to eq("/rails/active_storage/blobs/proxy/signed/file.jpg")
    end

    it "troca redirects internos antigos por proxy mesmo quando a URL ja e relativa" do
      url = "/rails/active_storage/representations/redirect/blob-signed/variation-signed/file.jpg"

      expect(helper.public_image_url(url)).to eq("/rails/active_storage/representations/proxy/blob-signed/variation-signed/file.jpg")
    end

    it "mantem URLs externas sem alterar" do
      url = "https://cdn.vistahost.com.br/salute/foto.jpg"

      expect(helper.public_image_url(url)).to eq(url)
    end

    it "gera caminho relativo para blobs do Active Storage" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("image"),
        filename: "foto.jpg",
        content_type: "image/jpeg"
      )

      expect(helper.public_image_url(blob)).to start_with("/rails/active_storage/blobs/proxy/")
    end

    it "gera caminho relativo para anexos Active Storage diretos" do
      setting = HomeSetting.instance
      setting.hero_background_desktop.attach(
        io: StringIO.new("image"),
        filename: "hero.jpg",
        content_type: "image/jpeg"
      )

      expect(helper.public_image_url(setting.hero_background_desktop)).to start_with("/rails/active_storage/blobs/proxy/")
    end

    it "gera caminho proxy para ActiveStorage::Attachment" do
      setting = HomeSetting.instance
      setting.hero_background_desktop.attach(
        io: StringIO.new("image"),
        filename: "attachment.jpg",
        content_type: "image/jpeg"
      )

      expect(helper.public_image_url(setting.hero_background_desktop.attachment)).to start_with("/rails/active_storage/blobs/proxy/")
    end
  end
end

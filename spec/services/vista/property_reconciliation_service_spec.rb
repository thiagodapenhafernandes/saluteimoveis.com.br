require "rails_helper"

RSpec.describe Vista::PropertyReconciliationService do
  around do |example|
    old_host = ENV["VISTA_HOST"]
    old_key = ENV["VISTA_KEY"]
    ENV["VISTA_HOST"] = "https://vista.example.test"
    ENV["VISTA_KEY"] = "test-key"
    example.run
  ensure
    ENV["VISTA_HOST"] = old_host
    ENV["VISTA_KEY"] = old_key
  end

  describe "photo preservation" do
    it "does not replace photos by default" do
      service = described_class.new(codigos: ["8395"], dry_run: true)

      expect(service.instance_variable_get(:@replace_photos)).to be(false)
    end

    it "does not detach existing ActiveStorage photos when Vista has no photos" do
      habitation = create(:habitation, codigo: "8395")
      habitation.photos.attach(
        io: StringIO.new("existing-image"),
        filename: "existing.jpg",
        content_type: "image/jpeg"
      )
      attachment = habitation.photos.attachments.first
      service = described_class.new(codigos: ["8395"], dry_run: false, replace_photos: true)
      counters = Hash.new(0)
      failures = []

      service.send(:sync_photos!, habitation, [], counters, failures)

      expect(habitation.reload.photos.attachments).to include(attachment)
      expect(counters[:photos_detached]).to eq(0)
      expect(failures).to be_empty
    end

    it "keeps the current picture payload when ActiveStorage photos already exist" do
      habitation = create(
        :habitation,
        codigo: "8395",
        pictures: [{ "url" => "https://spaces.example/current.jpg", "ordem" => 1 }]
      )
      habitation.photos.attach(
        io: StringIO.new("existing-image"),
        filename: "existing.jpg",
        content_type: "image/jpeg"
      )
      service = described_class.new(codigos: ["8395"], dry_run: false)
      incoming_photos = [{ "Foto" => "https://cdn.vistahost.com.br/new.jpg", "Ordem" => "1" }]

      payload = service.send(:pictures_payload_for_update, habitation, incoming_photos)

      expect(payload).to eq([{ "url" => "https://spaces.example/current.jpg", "ordem" => 1 }])
    end
  end

  describe "bathroom mapping" do
    it "uses the Vista form bathroom count before the aggregated bathroom count" do
      service = described_class.new(codigos: ["8627"], dry_run: true)

      count = service.send(
        :bathrooms_count,
        {
          "BanheiroSocialQtd" => "4",
          "TotalBanheiros" => "7"
        }
      )

      expect(count).to eq(4)
    end

    it "falls back to the aggregated bathroom count when the form count is blank" do
      service = described_class.new(codigos: ["8627"], dry_run: true)

      count = service.send(
        :bathrooms_count,
        {
          "BanheiroSocialQtd" => "",
          "TotalBanheiros" => "7"
        }
      )

      expect(count).to eq(7)
    end
  end

  describe "rent total mapping" do
    it "does not use condominium and IPTU as rent total when base rent is zero" do
      service = described_class.new(codigos: ["8628"], dry_run: true)

      total = service.send(
        :total_rent_cents,
        {
          "ValorLocacao" => "0",
          "ValorCondominio" => "1400",
          "ValorIptu" => "334",
          "ValorTotalAluguel" => "1734"
        }
      )

      expect(total).to eq(0)
    end

    it "uses the base rent as normalized rent total when rent is present" do
      service = described_class.new(codigos: ["8573"], dry_run: true)

      total = service.send(
        :total_rent_cents,
        {
          "ValorLocacao" => "7500",
          "ValorCondominio" => "0",
          "ValorIptu" => "0",
          "ValorTotalAluguel" => "7500"
        }
      )

      expect(total).to eq(750_000)
    end
  end

  describe "commission and rental management mapping" do
    let(:service) { described_class.new(codigos: ["8573"], dry_run: true) }

    it "uses the positive general commission percentage when the captador percentage is zero" do
      percentage = service.send(:commission_percentage, "0", "6")

      expect(percentage).to eq(BigDecimal("6"))
    end

    it "extracts the commission amount from Vista notes when the structured field is zero" do
      cents = service.send(
        :commission_amount_cents,
        {
          "ValorComissao" => "0",
          "ObsVenda" => "Tem Administração?  Sim\nValor da comissão: 7500"
        }
      )

      expect(cents).to eq(750_000)
    end

    it "uses Vista notes as a fallback for the Salute rental management flag" do
      flag = service.send(
        :rental_management_flag,
        {
          "ObsVenda" => "Método de garantia locação: Seguro Fiança\nTem Administração?  Sim"
        }
      )

      expect(flag).to be(true)
    end
  end
end

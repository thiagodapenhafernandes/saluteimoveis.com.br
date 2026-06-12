require "rails_helper"

RSpec.describe Vista::CleanImportService do
  describe "development code mapping" do
    let(:service) { described_class.new(dry_run: true) }

    before do
      service.instance_variable_set(:@development_codes, Set.new(["1950"]))
    end

    it "uses an explicit valid Vista development code" do
      code = service.send(
        :development_code_for,
        {
          "CODIGO_EMP" => "1950",
          "EMPREENDIMENTO" => "Blue Coast Tower"
        }
      )

      expect(code).to eq("1950")
    end

    it "does not infer a development link from the Vista development name" do
      code = service.send(
        :development_code_for,
        {
          "CODIGO_EMP" => "",
          "EMPREENDIMENTO" => "Moema Ii"
        }
      )

      expect(code).to be_nil
    end
  end

  describe "publication mapping" do
    let(:service) { described_class.new(dry_run: true) }

    before do
      service.instance_variable_set(:@categories, {})
      service.instance_variable_set(:@proprietor_id_by_vista_code, {})
      service.instance_variable_set(:@admin_user_id_by_vista_id, {})
      service.instance_variable_set(:@development_codes, Set.new)
      service.instance_variable_set(:@batch, instance_double(VistaImportBatch, id: 1))
    end

    it "ignores DA_WEB when setting the local publication flag" do
      attrs = service.send(
        :habitation_attrs,
        {
          "CODIGO" => "9101",
          "CATEGORIA" => "Apartamento",
          "STATUS" => "Venda",
          "DA_WEB" => "Sim",
          "EXIBIR_NO_SITE_SALUTE" => "Nao"
        },
        [],
        []
      )

      expect(attrs[:exibir_no_site_flag]).to be(false)
    end

    it "uses EXIBIR_NO_SITE_SALUTE for the local publication flag" do
      attrs = service.send(
        :habitation_attrs,
        {
          "CODIGO" => "9102",
          "CATEGORIA" => "Apartamento",
          "STATUS" => "Venda",
          "DA_WEB" => "Nao",
          "EXIBIR_NO_SITE_SALUTE" => "Sim"
        },
        [],
        []
      )

      expect(attrs[:exibir_no_site_flag]).to be(true)
    end
  end
end

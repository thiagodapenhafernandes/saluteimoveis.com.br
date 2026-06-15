require "rails_helper"

RSpec.describe SyncPropertyService do
  describe "publication mapping" do
    it "uses Vista ExibirNoSiteSalute for new local properties" do
      service = described_class.new("9201")

      attrs, = service.send(
        :map_vista_payload,
        {
          "Codigo" => "9201",
          "Categoria" => "Apartamento",
          "Status" => "Venda",
          "ExibirNoSite" => "Sim",
          "ExibirNoSiteSalute" => "Nao"
        }
      )

      expect(attrs[:exibir_no_site_flag]).to be(false)
    end

    it "preserves local publication for existing properties even when manual fields are not preserved" do
      service = described_class.new("9202", preserve_manual_fields: false)

      attrs = service.send(
        :filtered_habitation_attrs,
        { titulo_anuncio: "Atualizado pelo Vista", exibir_no_site_flag: false },
        existing_record: true
      )

      expect(attrs).to include(titulo_anuncio: "Atualizado pelo Vista")
      expect(attrs).not_to have_key(:exibir_no_site_flag)
    end
  end

  describe "development mapping" do
    it "ignores Vista development names for standalone houses without a development code" do
      attrs, = described_class.new("9203").send(
        :map_vista_payload,
        vista_payload(
          "Codigo" => "9203",
          "Categoria" => "Casa",
          "Empreendimento" => "Albatroz",
          "CodigoEmpreendimento" => ""
        )
      )

      expect(attrs[:codigo_empreendimento]).to be_nil
      expect(attrs[:nome_empreendimento]).to be_nil
    end

    it "keeps Vista development names for apartments even when the development code is not linked yet" do
      attrs, = described_class.new("9204").send(
        :map_vista_payload,
        vista_payload(
          "Codigo" => "9204",
          "Categoria" => "Apartamento",
          "Empreendimento" => "Residencial Teste",
          "CodigoEmpreendimento" => ""
        )
      )

      expect(attrs[:codigo_empreendimento]).to be_nil
      expect(attrs[:nome_empreendimento]).to eq("Residencial Teste")
    end

    it "keeps Vista development names when a standalone house has a development code" do
      attrs, = described_class.new("9205").send(
        :map_vista_payload,
        vista_payload(
          "Codigo" => "9205",
          "Categoria" => "Casa",
          "Empreendimento" => "Residencial Correto",
          "CodigoEmpreendimento" => "9901"
        )
      )

      expect(attrs[:codigo_empreendimento]).to eq("9901")
      expect(attrs[:nome_empreendimento]).to eq("Residencial Correto")
    end
  end

  def vista_payload(overrides = {})
    {
      "Status" => "Venda",
      "Categoria" => "Apartamento",
      "Dormitorios" => "0",
      "Suites" => "0",
      "TotalBanheiros" => "0",
      "Vagas" => "0",
      "AreaPrivativa" => "0",
      "AreaTotal" => "0",
      "ExibirNoSiteSalute" => "Nao"
    }.merge(overrides)
  end
end

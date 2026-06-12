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
end

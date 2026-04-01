require "builder"

module Portal
  class ChavesXmlSerializer
    def initialize(habitations:, integration:)
      @habitations = habitations
      @integration = integration
    end

    def to_xml
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct!
      xml.listings(portal: "chavesnamao", generated_at: Time.current.iso8601, account_id: @integration.account_id, publisher_id: @integration.publisher_id) do
        @habitations.each do |habitation|
          xml.listing do
            xml.code habitation.codigo
            xml.title(habitation.titulo_anuncio.presence || "Imóvel #{habitation.codigo}")
            xml.description(description_for(habitation))
            xml.status habitation.status
            xml.sale_price_cents habitation.valor_venda_cents
            xml.rent_price_cents habitation.valor_locacao_cents
            xml.city habitation.cidade
            xml.neighborhood habitation.bairro
            xml.state habitation.uf
            xml.address habitation.endereco
            xml.exibir_no_site habitation.exibir_no_site_flag
            xml.images do
              habitation.image_urls.first(15).each { |url| xml.image(url) }
            end
          end
        end
      end
      xml.target!
    end

    private

    def description_for(habitation)
      habitation.descricao_web.to_plain_text.presence || habitation.meta_description.to_plain_text.presence || "Sem descrição"
    rescue
      "Sem descrição"
    end
  end
end

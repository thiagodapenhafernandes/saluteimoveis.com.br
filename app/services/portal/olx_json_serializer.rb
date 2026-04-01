module Portal
  class OlxJsonSerializer
    def initialize(habitations:, integration:, portal:)
      @habitations = habitations
      @integration = integration
      @portal = portal
    end

    def as_json
      {
        portal: @portal,
        generated_at: Time.current.iso8601,
        account_id: @integration.account_id,
        publisher_id: @integration.publisher_id,
        listings: @habitations.map { |habitation| serialize_listing(habitation) }
      }
    end

    private

    def serialize_listing(habitation)
      {
        code: habitation.codigo,
        title: habitation.titulo_anuncio.presence || "Imóvel #{habitation.codigo}",
        description: habitation.descricao_web.to_plain_text.presence || habitation.meta_description.to_plain_text.presence || "Sem descrição",
        status: habitation.status,
        business_types: business_types(habitation),
        sale_price_cents: habitation.valor_venda_cents,
        rent_price_cents: habitation.valor_locacao_cents,
        city: habitation.cidade,
        neighborhood: habitation.bairro,
        state: habitation.uf,
        address: habitation.endereco,
        exibir_no_site: habitation.exibir_no_site_flag,
        images: habitation.image_urls.first(15)
      }
    rescue
      {
        code: habitation.codigo,
        title: habitation.titulo_anuncio.presence || "Imóvel #{habitation.codigo}",
        description: "Sem descrição",
        status: habitation.status,
        business_types: business_types(habitation),
        sale_price_cents: habitation.valor_venda_cents,
        rent_price_cents: habitation.valor_locacao_cents,
        city: habitation.cidade,
        neighborhood: habitation.bairro,
        state: habitation.uf,
        address: habitation.endereco,
        exibir_no_site: habitation.exibir_no_site_flag,
        images: habitation.image_urls.first(15)
      }
    end

    def business_types(habitation)
      types = []
      types << "venda" if habitation.valor_venda_cents.to_i.positive?
      types << "aluguel" if habitation.valor_locacao_cents.to_i.positive?
      types
    end
  end
end

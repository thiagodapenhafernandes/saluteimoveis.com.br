module Seo
  class PropertyMetadataBuilder
    include Rails.application.routes.url_helpers

    SITE_NAME = "Salute Imóveis".freeze
    DESCRIPTION_LIMIT = 220

    def initialize(habitation)
      @habitation = habitation
    end

    def attributes
      {
        canonical_key: canonical_key,
        page_name: page_name,
        page_type: page_type,
        canonical_path: canonical_path,
        canonical_url: canonical_path,
        meta_title: title,
        meta_description: description,
        meta_keywords: keywords,
        og_title: title,
        og_description: description
      }.compact
    end

    def canonical_key
      "property:#{identifier}"
    end

    def page_name
      "imovel:#{identifier}"
    end

    def page_type
      @habitation.empreendimento? ? "development_show" : "property_show"
    end

    def canonical_path
      habitation_path(@habitation)
    end

    def title
      base_title = @habitation.display_title.to_s.squish.presence || @habitation.categoria.to_s.squish.presence || "Imóvel #{@habitation.codigo}"
      base_title.include?(SITE_NAME) ? base_title : "#{base_title} | #{SITE_NAME}"
    end

    def description
      source = @habitation.display_description_plain_text.presence ||
               @habitation.seo_description.to_s.presence ||
               @habitation.display_title.to_s

      source.to_s.squish.truncate(DESCRIPTION_LIMIT, separator: " ")
    end

    def keywords
      @habitation.seo_keywords.to_s.presence
    end

    private

    def identifier
      @habitation.codigo.presence || @habitation.id
    end
  end
end

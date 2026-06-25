require "builder"

module Portal
  class VrsyncXmlSerializer
    SCHEMA_URL = "http://www.vivareal.com/schemas/1.0/VRSync".freeze
    SCHEMA_XSD = "http://xml.vivareal.com/vrsync.xsd".freeze
    DEFAULT_APP_HOST = "https://saluteimoveis.com.br"
    SUPPORTED_IMAGE_EXTENSION = /\.(jpe?g)(?:[?#].*)?\z/i
    PUBLICATION_TYPES = {
      "padrao" => "STANDARD",
      "destaque" => "PREMIUM",
      "super_destaque" => "SUPER_PREMIUM",
      "destaque_exclusivo" => "PREMIERE_1",
      "destaque_superior" => "PREMIERE_2",
      "destaque_triplo" => "TRIPLE"
    }.freeze

    def initialize(habitations:, integration:)
      @habitations = habitations
      @integration = integration
    end

    def self.exportable?(habitation, image_urls: nil, app_host: DEFAULT_APP_HOST)
      image_urls ||= image_urls_for(habitation, app_host: app_host)

      image_urls.present? &&
        habitation.codigo.to_s.strip.present? &&
        title_for(habitation).length.between?(10, 100) &&
        sanitize_cep(habitation.cep).present? &&
        habitation.uf.to_s.strip.present? &&
        habitation.cidade.to_s.strip.present? &&
        habitation.bairro.to_s.strip.present? &&
        habitation.endereco.to_s.strip.present?
    end

    def self.image_urls_for(habitation, app_host: DEFAULT_APP_HOST)
      habitation.image_urls.filter_map do |url|
        absolute = absolute_url(url, app_host: app_host)
        absolute if supported_image_url?(absolute)
      end
    end

    def self.title_for(habitation)
      habitation.titulo_anuncio.presence || "Imóvel #{habitation.codigo}"
    end

    def self.sanitize_cep(cep)
      cep.to_s.gsub(/\D/, "")
    end

    def self.absolute_url(url, app_host: DEFAULT_APP_HOST)
      value = url.to_s.strip
      return nil if value.blank?
      return value if value.match?(%r{\Ahttps?://}i)

      path = value.start_with?("/") ? value : "/#{value}"
      "#{app_host.to_s.sub(%r{/*\z}, "")}#{path}"
    end

    def self.supported_image_url?(url)
      url.to_s.match?(SUPPORTED_IMAGE_EXTENSION)
    end

    def to_xml
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct!

      xml.ListingDataFeed(
        "xmlns" => SCHEMA_URL,
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" => "#{SCHEMA_URL} #{SCHEMA_XSD}"
      ) do
        xml.Header do
          xml.Provider "Salute"
          xml.Email "contato@saluteimoveis.com.br"
          xml.ContactName "SALUTE IMOVEIS"
          xml.PublishDate Time.current.iso8601
          xml.Telephone "(47) 3311-1067"
        end

        xml.Listings do
          @habitations.each do |habitation|
            image_urls = image_urls_for(habitation)
            next unless valid_listing_for_vrsync?(habitation, image_urls)

            xml.Listing do
              xml.ListingID habitation.codigo
              xml.UpdateDate (habitation.updated_at || Time.current).iso8601
              xml.ContactInfo do
                xml.Name "SALUTE IMOVEIS"
                xml.Email "contato@saluteimoveis.com.br"
                xml.Telephone "(47) 3311-1067"
              end

              xml.Details do
                xml.Bathrooms habitation.banheiros_qtd.to_i
                xml.Bedrooms habitation.dormitorios_qtd.to_i
                xml.Garage habitation.vagas_qtd.to_i
                if (la = integer_or_zero(habitation.area_privativa_m2)).positive?
                  xml.LivingArea("unit" => "square metres") { xml.text!(la.to_s) }
                end
                if (lot = integer_or_zero(habitation.area_total_m2)).positive?
                  xml.LotArea("unit" => "square metres") { xml.text!(lot.to_s) }
                end
                xml.PropertyAdministrationFee cents_to_units(habitation.valor_condominio_cents)
                xml.PropertyType property_type_for(habitation)
                xml.Suites habitation.suites_qtd.to_i
                if habitation.valor_iptu_cents.to_i.positive?
                  xml.Iptu("currency" => "BRL", "period" => "Monthly") { xml.text!(cents_to_units(habitation.valor_iptu_cents).to_s) }
                end
                xml.Description { xml.cdata!(description_for(habitation)) }

                if habitation.valor_locacao_cents.to_i.positive?
                  xml.RentalPrice("currency" => "BRL", "period" => "Monthly") { xml.text!(cents_to_units(habitation.valor_locacao_cents).to_s) }
                end

                if habitation.valor_venda_cents.to_i.positive?
                  xml.ListPrice("currency" => "BRL") { xml.text!(cents_to_units(habitation.valor_venda_cents).to_s) }
                end

                xml.Features do
                  feature_list_for(habitation).each { |feature| xml.Feature feature }
                end
              end

              xml.Location("displayAddress" => display_address_for(habitation)) do
                xml.Country("abbreviation" => "BR") { xml.text!("Brasil") }
                xml.State("abbreviation" => habitation.uf.to_s) { xml.text!(state_name_for(habitation.uf)) }
                xml.City { xml.cdata!(habitation.cidade.to_s) }
                xml.Neighborhood { xml.cdata!(habitation.bairro.to_s) }
                xml.Address { xml.cdata!(habitation.endereco.to_s) }
                xml.StreetNumber habitation.numero.to_s
                xml.Complement habitation.complemento.to_s if habitation.complemento.to_s.strip.present?
                xml.PostalCode sanitize_cep(habitation.cep)
                if (lat = coordinate(habitation, :latitude))
                  xml.Latitude lat
                end
                if (lng = coordinate(habitation, :longitude))
                  xml.Longitude lng
                end
              end

              xml.PublicationType publication_type_for(habitation)
              xml.Title { xml.cdata!(title_for(habitation)) }

              xml.Media do
                image_urls.first(30).each_with_index do |url, idx|
                  attrs = { "medium" => "image", "caption" => "" }
                  attrs["primary"] = "true" if idx.zero?
                  xml.Item(attrs) { xml.text!(url.to_s) }
                end
              end

              xml.TransactionType transaction_type_for(habitation)
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

    def title_for(habitation)
      self.class.title_for(habitation)
    end

    # Valores oficiais do enum VRSync.
    # Ref: https://developers.grupozap.com/feeds/vrsync/elements/details.html
    def property_type_for(habitation)
      category = habitation.categoria.to_s.downcase

      case category
      when /cobertura/                                   then "Residential / Penthouse"
      when /flat/                                        then "Residential / Flat"
      when /loft/                                        then "Residential / Loft"
      when /kitnet/                                      then "Residential / Kitnet"
      when /studio/                                      then "Residential / Studio"
      when /sobrado/                                     then "Residential / Sobrado"
      when /casa em condom/                              then "Residential / Village House"
      when /casa comercial/                              then "Commercial / Edificio Comercial"
      when /casa/                                        then "Residential / Home"
      when /apartamento/                                 then "Residential / Apartment"
      when /condomínio industrial|condominio industrial/ then "Commercial / Industrial"
      when /condomínio|condominio/                       then "Residential / Condo"
      when /chácara|chacara/                             then "Residential / Farm Ranch"
      when /sítio|sitio/                                 then "Residential / Agricultural"
      when /terreno industrial|terreno comercial|área|area/ then "Commercial / Land Lot"
      when /terreno/                                     then "Residential / Land Lot"
      when /galpão|galpao/                               then "Commercial / Industrial"
      when /sala|conjunto/                               then "Commercial / Office"
      when /loja|ponto comercial/                        then "Commercial / Business"
      when /prédio comercial|predio comercial/           then "Commercial / Edificio Comercial"
      when /empreendimento/                              then "Commercial / Edificio Residencial"
      else                                                    "Residential / Apartment"
      end
    end

    def display_address_for(habitation)
      case habitation.try(:divulgar_endereco_viva_real).to_s
      when "exata" then return "All"
      when "rua" then return "Street"
      when "bairro" then return "Neighborhood"
      end

      return "Neighborhood" if habitation.endereco.to_s.strip.blank?
      return "Street" if habitation.numero.to_s.strip.present?
      "Street"
    end

    def sanitize_cep(cep)
      self.class.sanitize_cep(cep)
    end

    def coordinate(habitation, kind)
      source = habitation.address || habitation
      value = source.respond_to?(kind) ? source.send(kind) : nil
      return nil if value.blank?
      number = value.to_f
      return nil if number.zero?
      number
    end

    def publication_type_for(habitation)
      explicit = PUBLICATION_TYPES[habitation.try(:tipo_publicacao_viva_real).to_s]
      return explicit if explicit.present?

      habitation.destaque_web_flag ? "PREMIUM" : "STANDARD"
    end

    def transaction_type_for(habitation)
      has_sale = habitation.valor_venda_cents.to_i.positive?
      has_rent = habitation.valor_locacao_cents.to_i.positive?

      return "Sale/Rent" if has_sale && has_rent
      return "For Sale" if has_sale && !has_rent
      return "For Rent" if has_rent && !has_sale

      "For Sale"
    end

    def feature_list_for(habitation)
      values = []
      values.concat(Array(habitation.infra_estrutura))
      values.concat(Array(habitation.caracteristicas&.values)) if habitation.caracteristicas.respond_to?(:values)
      values.concat(Array(habitation.unique_features)) if habitation.respond_to?(:unique_features)

      values.map { |value| value.to_s.strip }.reject(&:blank?).uniq.first(40)
    end

    def integer_or_zero(value)
      value.to_f.to_i
    end

    def cents_to_units(cents)
      cents.to_i / 100
    end

    def valid_listing_for_vrsync?(habitation, image_urls)
      self.class.exportable?(habitation, image_urls: image_urls, app_host: app_host)
    end

    def image_urls_for(habitation)
      self.class.image_urls_for(habitation, app_host: app_host)
    end

    def absolute_url(url)
      self.class.absolute_url(url, app_host: app_host)
    end

    def supported_image_url?(url)
      self.class.supported_image_url?(url)
    end

    def app_host
      ENV.fetch("APP_HOST", DEFAULT_APP_HOST).to_s.sub(%r{/*\z}, "")
    end

    def state_name_for(uf)
      mapping = {
        "SC" => "Santa Catarina", "PR" => "Paraná", "SP" => "São Paulo", "RS" => "Rio Grande do Sul",
        "RJ" => "Rio de Janeiro", "MG" => "Minas Gerais", "ES" => "Espírito Santo", "DF" => "Distrito Federal",
        "GO" => "Goiás", "MS" => "Mato Grosso do Sul", "MT" => "Mato Grosso", "BA" => "Bahia"
      }
      mapping[uf.to_s.upcase] || uf.to_s
    end
  end
end

module Dwv
  class PropertyImportService
    DEFAULT_CATEGORY = "Apartamento".freeze

    def self.extract_collection(payload)
      case payload
      when Array
        payload
      when Hash
        payload["data"] || payload[:data] || payload["properties"] || payload[:properties] || payload["items"] || payload[:items] || []
      else
        []
      end
    end

    def self.extract_property_id(payload)
      value(payload, ["id"], ["propertyId"], ["property_id"], ["codigo_dwv"], ["codigoDwv"], ["codigo"]) ||
        value(payload, ["data", "id"], ["data", "propertyId"], ["data", "property_id"], ["data", "codigo_dwv"], ["data", "codigoDwv"], ["data", "codigo"])
    end

    def initialize(payload)
      @raw_payload = payload || {}
      @payload = unwrap_payload(@raw_payload)
    end

    def perform
      dwv_id = self.class.extract_property_id(@payload).to_s
      raise "ID do imóvel DWV não encontrado no payload." if dwv_id.blank?

      codigo = value(["reference"], ["codigo"], ["code"]).to_s.strip
      codigo = "DWV-#{dwv_id}" if codigo.blank?

      habitation = find_existing_habitation(dwv_id: dwv_id, codigo: codigo)
      habitation ||= Habitation.new
      existing_record = habitation.persisted?

      if !existing_record && insufficient_payload_for_new_record?
        raise "Payload DWV incompleto para novo cadastro (id=#{dwv_id})."
      end

      habitation.assign_attributes(
        codigo_dwv: dwv_id,
        imovel_dwv: "Sim",
        status: map_status(value(["status"], ["property_status"])) || habitation.status,
        valor_venda_cents: to_cents(value(["price"], ["sale_price"], ["valor_venda"], ["unit", "price"])) || habitation.valor_venda_cents,
        valor_locacao_cents: to_cents(value(["rent_price"], ["valor_locacao"], ["unit", "rent"])) || habitation.valor_locacao_cents,
        exibir_no_site_flag: active_on_site?
      )

      unless existing_record
        habitation.assign_attributes(
          codigo: resolve_codigo_for(habitation, codigo),
          titulo_anuncio: value(["title"], ["advertisement_title"], ["name"], ["titulo"]).to_s.strip.presence || habitation.titulo_anuncio,
          categoria: normalize_category(value(["type", "name"], ["type"], ["category"], ["categoria"])) || habitation.categoria || DEFAULT_CATEGORY,
          situacao: map_situation(value(["property_condition"], ["construction_stage_raw"], ["situacao"])) || habitation.situacao,
          dormitorios_qtd: to_int(value(["bedrooms"], ["unit_bedrooms"], ["quartos"], ["unit", "dorms"])) || habitation.dormitorios_qtd,
          suites_qtd: to_int(value(["unit_suites"], ["suites"], ["suites_qtd"], ["unit", "suites"])) || habitation.suites_qtd,
          banheiros_qtd: to_int(value(["bathrooms"], ["banheiros"], ["total_bathrooms"], ["unit", "bathroom"])) || habitation.banheiros_qtd,
          vagas_qtd: to_int(value(["unit_parking_spaces"], ["parking_spaces"], ["vagas"], ["unit", "parking_spaces"])) || habitation.vagas_qtd,
          area_privativa_m2: to_decimal(value(["private_area"], ["unit_private_area"], ["area_privativa"], ["area_privativa_m2"], ["unit", "private_area"], ["unit", "util_area"])) || habitation.area_privativa_m2,
          area_total_m2: to_decimal(value(["total_area"], ["unit_total_area"], ["area_total"], ["area_total_m2"], ["unit", "total_area"])) || habitation.area_total_m2,
          pictures: extract_pictures.presence || habitation.pictures
        )
      end

      habitation.last_sync_at = Time.current
      habitation.last_sync_status = "success"
      habitation.last_sync_message = existing_record ? "Sincronizado via DWV (update limitado: valor/disponibilidade)" : "Sincronizado via DWV (cadastro inicial)"

      Habitation.transaction do
        habitation.save!

        unless existing_record
          address_attrs = extract_address
          if address_attrs.present?
            address = habitation.address || habitation.build_address
            address.assign_attributes(address_attrs)
            address.save!
          end
        end
      end

      { success: true, habitation: habitation }
    rescue => e
      if defined?(habitation) && habitation&.persisted?
        habitation.update(
          last_sync_at: Time.current,
          last_sync_status: "error",
          last_sync_message: e.message
        )
      end
      raise e
    end

    private

    def self.value(payload, *paths)
      paths.each do |path|
        current = payload
        path.each do |segment|
          if current.is_a?(Hash)
            current = current[segment] || current[segment.to_sym]
          else
            current = nil
          end
          break if current.nil?
        end
        return current unless current.nil?
      end
      nil
    end

    def value(*paths)
      self.class.value(@payload, *paths)
    end

    def unwrap_payload(payload)
      return {} unless payload.is_a?(Hash)

      data = payload["data"] || payload[:data]
      return data if data.is_a?(Hash)

      payload
    end

    def find_existing_habitation(dwv_id:, codigo:)
      # Chave principal da integração DWV
      by_dwv_code = Habitation.where(codigo_dwv: dwv_id, imovel_dwv: "Sim")
      return pick_best_candidate(by_dwv_code) if by_dwv_code.exists?

      # Compatibilidade: legados com codigo_dwv preenchido e flag fora do padrão.
      by_dwv_code_legacy = Habitation.where(codigo_dwv: dwv_id)
      return pick_best_candidate(by_dwv_code_legacy) if by_dwv_code_legacy.exists?

      return nil if codigo.blank?

      # Reaproveita apenas imóveis já marcados como DWV para evitar colidir com cadastro manual.
      by_code_and_dwv_flag = Habitation.where(codigo: codigo, imovel_dwv: "Sim")
      return pick_best_candidate(by_code_and_dwv_flag) if by_code_and_dwv_flag.exists?

      # Compatibilidade: alguns legados podem ter codigo_dwv preenchido e flag em branco.
      by_code_and_dwv_code = Habitation.where(codigo: codigo).where.not(codigo_dwv: [nil, ""])
      return pick_best_candidate(by_code_and_dwv_code) if by_code_and_dwv_code.exists?

      nil
    end

    def pick_best_candidate(scope)
      scope.order(Arel.sql("CASE WHEN codigo_dwv IS NULL OR codigo_dwv = '' THEN 1 ELSE 0 END"), updated_at: :desc).first
    end

    def resolve_codigo_for(habitation, incoming_codigo)
      current = habitation.codigo.to_s.strip
      return incoming_codigo if current.blank?

      # Mantém código já existente para não quebrar links/referências internas.
      current
    end

    def normalize_category(raw)
      value = raw.to_s.strip
      return nil if value.blank?

      known = Habitation::CATEGORIES.find { |item| item.casecmp(value).zero? }
      return known if known.present?

      return "Sala Comercial" if value.match?(/comercial|sala|loja|galp[aã]o|pr[ée]dio/i)
      return "Terreno" if value.match?(/terreno|lote|[áa]rea/i)
      return "Casa" if value.match?(/casa|sobrado/i)

      "Apartamento"
    end

    def map_status(raw)
      value = raw.to_s.strip.downcase
      return nil if value.blank?
      return "Venda e Locação" if value.include?("sale") && value.include?("rent")
      return "Venda" if value.include?("sale") || value.include?("venda")
      return "Locação" if value.include?("rent") || value.include?("loca") || value.include?("alug")
      return "Suspenso" if value.include?("inactive") || value.include?("inativo")

      value.titleize
    end

    def map_situation(raw)
      value = raw.to_s.strip.downcase
      return nil if value.blank?
      return "Lançamento" if value.include?("pre-market") || value.include?("launch") || value.include?("lançamento")
      return "Em Obras" if value.include?("under construction") || value.include?("obra")
      return "Novo" if value == "new"
      return "Usado" if value == "used"

      value.titleize
    end

    def active_on_site?
      status = value(["status"], ["integration_status"]).to_s.downcase
      deleted = value(["deleted"])
      return false if deleted == true || deleted.to_s == "true"
      return false if status == "inactive" || status == "auto_inactive"

      true
    end

    def extract_address
      address = value(["address"]) || {}
      building_address = value(["building", "address"]) || {}

      city = self.class.value(address, ["city"]) || self.class.value(building_address, ["city"]) || value(["city"])
      state = self.class.value(address, ["state"], ["uf"]) || self.class.value(building_address, ["state"], ["uf"]) || value(["state"], ["uf"])
      district = self.class.value(address, ["district"], ["neighborhood"], ["bairro"]) || self.class.value(building_address, ["district"], ["neighborhood"], ["bairro"]) || value(["neighborhood"], ["bairro"])
      street = self.class.value(address, ["street"], ["logradouro"]) || self.class.value(building_address, ["street"], ["logradouro"]) || value(["street"], ["address"])

      normalized = {
        logradouro: street.to_s.strip,
        numero: (self.class.value(address, ["number"]) || self.class.value(building_address, ["number"])).to_s.strip.presence,
        complemento: (self.class.value(address, ["complement"]) || self.class.value(building_address, ["complement"])).to_s.strip.presence,
        bairro: district.to_s.strip,
        cidade: city.to_s.strip,
        uf: state.to_s.strip.upcase.first(2),
        cep: (self.class.value(address, ["zipCode"], ["zip_code"], ["cep"]) || self.class.value(building_address, ["zipCode"], ["zip_code"], ["cep"])).to_s.strip.presence,
        latitude: self.class.value(address, ["latitude"]) || self.class.value(building_address, ["latitude"]) || value(["latitude"]),
        longitude: self.class.value(address, ["longitude"]) || self.class.value(building_address, ["longitude"]) || value(["longitude"])
      }

      required = normalized.values_at(:logradouro, :bairro, :cidade, :uf)
      return nil if required.any?(&:blank?)

      normalized
    end

    def extract_pictures
      raw_sources = []
      raw_sources += Array(value(["images"]))
      raw_sources += Array(value(["pictures"]))
      raw_sources += Array(value(["photos"]))
      raw_sources += Array(value(["selected_photos"]))
      raw_sources += Array(value(["unit", "images"]))
      raw_sources += Array(value(["unit", "pictures"]))
      raw_sources += Array(value(["unit", "photos"]))
      raw_sources += Array(value(["building", "gallery"]))
      raw_sources << value(["building", "cover"])

      normalized = raw_sources.compact.map.with_index do |image, index|
        picture_from(image, fallback_order: index + 1)
      end.compact

      unique = normalized.uniq { |pic| pic["url"].to_s.strip }
      return [] if unique.blank?

      unique.first["principal"] = true
      unique.each_with_index do |pic, index|
        pic["ordem"] = index + 1 if pic["ordem"].to_i <= 0
      end
      unique
    end

    def picture_from(image, fallback_order:)
      return if image.nil?

      if image.is_a?(String)
        return { "url" => image, "ordem" => fallback_order, "principal" => false }
      end

      return unless image.is_a?(Hash)

      sizes = image["sizes"] || image[:sizes]
      medium_url = if sizes.is_a?(Hash)
        sizes["medium"] || sizes[:medium] || sizes["small"] || sizes[:small]
      end

      url = image["url"] || image[:url] || image["image"] || image[:image]
      url ||= image.dig("file", "url") || image.dig(:file, :url)
      return if url.blank?

      {
        "url" => url,
        "url_pequena" => image["thumbnail"] || image[:thumbnail] || medium_url,
        "ordem" => image["order"] || image[:order] || fallback_order,
        "principal" => image["featured"] == true || image[:featured] == true
      }
    end

    def to_cents(raw)
      return nil if raw.blank?
      number = raw.to_s.gsub(/[^\d,.-]/, "").tr(",", ".").to_f
      return nil if number <= 0

      (number * 100).to_i
    end

    def to_int(raw)
      return nil if raw.blank?
      value = raw.to_i
      value.negative? ? 0 : value
    end

    def to_decimal(raw)
      return nil if raw.blank?
      number = raw.to_s.gsub(/[^\d,.-]/, "").tr(",", ".").to_f
      return nil if number <= 0

      number
    end

    def insufficient_payload_for_new_record?
      return false if active_on_site?

      # Some inactive/deleted DWV entries come with only metadata and no usable fields.
      # Skip creating new local records in this scenario to avoid "empty" properties.
      title_present = value(["title"], ["advertisement_title"], ["name"], ["titulo"]).to_s.strip.present?
      category_present = value(["type", "name"], ["type"], ["category"], ["categoria"]).to_s.strip.present?
      has_any_price = to_cents(value(["price"], ["sale_price"], ["valor_venda"], ["unit", "price"])).present? ||
                      to_cents(value(["rent_price"], ["valor_locacao"], ["unit", "rent"])).present?
      has_location = extract_address.present? ||
                     value(["city"], ["neighborhood"], ["bairro"], ["address", "city"], ["address", "district"]).to_s.strip.present?
      has_pictures = extract_pictures.present?

      !title_present && !category_present && !has_any_price && !has_location && !has_pictures
    end
  end
end

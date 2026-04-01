# frozen_string_literal: true

module Loft
  class PropertyCodesService
    LIST_PATH = "/imoveis/listar"
    MAX_PAGE_SIZE = 50
    METADATA_KEYS = %w[total paginas pagina quantidade].freeze

    def initialize(host:, token:)
      @host = host.to_s.strip.chomp("/")
      @token = token.to_s.strip
    end

    def call(mode: "full", batch_size: nil)
      normalized_mode = mode.to_s == "batch" ? "batch" : "full"
      desired_count = batch_size.to_i.positive? ? batch_size.to_i : 100

      if normalized_mode == "batch"
        fetch_batch_codes(desired_count: desired_count)
      else
        fetch_all_codes
      end
    end

    private

    def fetch_all_codes
      first_page = fetch_page(page: 1, page_size: MAX_PAGE_SIZE, show_total: true)
      total_pages = first_page["paginas"].to_i
      total_remote = first_page["total"].to_i
      codes = extract_codes(first_page)

      total_pages = 1 if total_pages <= 0 && codes.any?

      2.upto(total_pages) do |page|
        response = fetch_page(page: page, page_size: MAX_PAGE_SIZE, show_total: false)
        page_codes = extract_codes(response)
        break if page_codes.empty?

        codes.concat(page_codes)
      end

      unique_codes = codes.map(&:to_s).reject(&:blank?).uniq
      {
        codes: unique_codes,
        remote_total: total_remote.positive? ? total_remote : unique_codes.size,
        total_pages: total_pages
      }
    end

    def fetch_batch_codes(desired_count:)
      target = desired_count.clamp(1, 1000)
      page_size = [MAX_PAGE_SIZE, target].min
      page = 1
      total_pages = 1
      total_remote = 0
      codes = []

      while codes.size < target && page <= total_pages
        response = fetch_page(page: page, page_size: page_size, show_total: page == 1)
        total_pages = response["paginas"].to_i if page == 1
        total_pages = 1 if total_pages <= 0
        total_remote = response["total"].to_i if page == 1

        page_codes = extract_codes(response)
        break if page_codes.empty?

        codes.concat(page_codes)
        page += 1
      end

      unique_codes = codes.map(&:to_s).reject(&:blank?).uniq.first(target)
      {
        codes: unique_codes,
        remote_total: total_remote.positive? ? total_remote : unique_codes.size,
        total_pages: total_pages
      }
    end

    def fetch_page(page:, page_size:, show_total:)
      query = {
        fields: ["Codigo"],
        paginacao: {
          pagina: page.to_i,
          quantidade: page_size.to_i.clamp(1, MAX_PAGE_SIZE)
        }
      }

      params = {
        key: @token,
        pesquisa: query.to_json
      }
      params[:showtotal] = 1 if show_total

      response = RestClient.get("#{@host}#{LIST_PATH}", params: params, accept: :json)
      parsed = JSON.parse(response.body)
      if parsed.is_a?(Hash)
        status_code = parsed["status"].to_i
        if status_code >= 400
          message = parsed["message"].presence || parsed["msg"].presence || "erro na API"
          raise "Falha ao listar imóveis na Vista (página #{page}): #{message}"
        end

        return parsed
      end

      raise "Resposta inválida ao listar imóveis na Vista."
    rescue RestClient::ExceptionWithResponse => e
      raise "Falha ao listar imóveis na Vista (página #{page}): #{e.response&.code || e.message}"
    rescue JSON::ParserError
      raise "Resposta inválida ao listar imóveis na Vista (página #{page})."
    end

    def extract_codes(response_hash)
      payload = response_hash.except(*METADATA_KEYS)

      payload.values.each_with_object([]) do |item, acc|
        next unless item.is_a?(Hash)

        code = item["Codigo"].to_s.strip
        acc << code if code.present?
      end
    end
  end
end

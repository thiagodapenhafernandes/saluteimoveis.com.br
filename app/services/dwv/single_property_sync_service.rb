module Dwv
  class SinglePropertySyncService
    Result = Struct.new(:success, :habitation, :deleted, :message, keyword_init: true) do
      def success?
        success
      end

      def deleted?
        deleted
      end
    end

    DEFAULT_BASE_URL = "https://agencies.dwvapp.com.br".freeze

    def initialize(property_id:, client: nil)
      @property_id = property_id.to_s.strip
      @client = client
    end

    def call
      raise "Informe o ID do imóvel na DWV." if property_id.blank?

      payload = client.property_details(property_id)
      import_result = Dwv::PropertyImportService.new(payload).perform

      if import_result[:deleted]
        habitation = import_result[:habitation]
        local_code = habitation&.codigo
        message = local_code.present? ? "Imóvel DWV ##{property_id} excluído. Código local: #{local_code}" : "Imóvel DWV ##{property_id} já estava removido na DWV."
        Result.new(success: true, habitation: habitation, deleted: true, message: message)
      else
        habitation = import_result.fetch(:habitation)
        Result.new(
          success: true,
          habitation: habitation,
          deleted: false,
          message: "Imóvel DWV ##{property_id} sincronizado. Código local: #{habitation.codigo}"
        )
      end
    end

    private

    attr_reader :property_id

    def client
      @client ||= Dwv::Client.new(
        token: Setting.get("dwv_api_token"),
        base_url: Setting.get("dwv_base_url", DEFAULT_BASE_URL)
      )
    end
  end
end

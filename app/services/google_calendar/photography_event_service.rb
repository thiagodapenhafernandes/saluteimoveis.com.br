require "google/apis/calendar_v3"
require "googleauth"

module GoogleCalendar
  class PhotographyEventService
    Result = Struct.new(:success, :event_id, :html_link, :error_message, keyword_init: true) do
      def success?
        success
      end
    end

    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR
    TIME_ZONE = "America/Sao_Paulo".freeze
    DEFAULT_DURATION = 45.minutes

    def self.test_connection
      service = build_service
      calendar = service.get_calendar(Habitation.google_photography_calendar_id)
      Result.new(success: true, event_id: calendar.id, html_link: nil, error_message: nil)
    rescue StandardError => e
      Rails.logger.warn("[GoogleCalendar::PhotographyEventService] test_connection failed: #{e.class}: #{e.message}")
      Result.new(success: false, event_id: nil, html_link: nil, error_message: e.message)
    end

    def self.build_service
      validate_configuration!

      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(Habitation.google_photography_credentials_path),
        scope: SCOPE
      )
      service
    end

    def self.validate_configuration!
      raise ArgumentError, "Google Agenda de fotografia desativado." unless Habitation.google_photography_calendar_enabled?
      raise ArgumentError, "Informe o ID da agenda do Google." if Habitation.google_photography_calendar_id.blank?
      raise ArgumentError, "Informe o caminho do JSON da conta de serviço." if Habitation.google_photography_credentials_path.blank?
      raise ArgumentError, "Arquivo JSON da conta de serviço não encontrado." unless File.exist?(Habitation.google_photography_credentials_path)
    end

    def initialize(habitation)
      @habitation = habitation
    end

    def call
      raise ArgumentError, "Informe a data/hora agendada com fotógrafo." if habitation.photo_session_requested_at.blank?

      event = build_event
      response = if habitation.photo_calendar_event_id.present?
                   service.update_event(calendar_id, habitation.photo_calendar_event_id, event)
                 else
                   service.insert_event(calendar_id, event)
                 end

      Result.new(success: true, event_id: response.id, html_link: response.html_link, error_message: nil)
    rescue StandardError => e
      Rails.logger.error("[GoogleCalendar::PhotographyEventService] sync failed for habitation_id=#{habitation.id}: #{e.class}: #{e.message}")
      Result.new(success: false, event_id: nil, html_link: nil, error_message: e.message)
    end

    private

    attr_reader :habitation

    def service
      @service ||= self.class.build_service
    end

    def calendar_id
      Habitation.google_photography_calendar_id
    end

    def build_event
      Google::Apis::CalendarV3::Event.new(
        summary: event_summary,
        description: event_description,
        location: event_location,
        start: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: starts_at.iso8601,
          time_zone: TIME_ZONE
        ),
        end: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: ends_at.iso8601,
          time_zone: TIME_ZONE
        )
      )
    end

    def starts_at
      @starts_at ||= habitation.photo_session_requested_at.in_time_zone(TIME_ZONE)
    end

    def ends_at
      starts_at + DEFAULT_DURATION
    end

    def event_summary
      reference = habitation.codigo.presence || "sem código"
      title = habitation.display_title.presence || habitation.categoria.presence || "Imóvel"
      "Fotografia - #{reference} - #{title}"
    end

    def event_description
      [
        "Imóvel: #{habitation.display_title.presence || habitation.categoria.presence || "Sem título"}",
        "Código: #{habitation.codigo.presence || "Sem código"}",
        "Captador: #{habitation.admin_user&.name.presence || "Sem captador"}",
        "Proprietário: #{habitation.proprietario.presence || "Não informado"}",
        "Telefone proprietário: #{habitation.proprietario_celular.presence || habitation.proprietario_telefone.presence || "Não informado"}",
        ("Observações de visita: #{habitation.observacoes_visitas}" if habitation.observacoes_visitas.present?),
        ("Observações internas: #{habitation.descricao_interna}" if habitation.descricao_interna.present?)
      ].compact.join("\n")
    end

    def event_location
      [
        habitation.logradouro,
        habitation.numero,
        habitation.bairro,
        habitation.cidade,
        habitation.uf
      ].compact_blank.join(", ")
    end
  end
end

module Admin
  class SchedulingIntegrationsController < Admin::BaseController
    before_action :authorize_view!
    before_action :authorize_manage!, only: %i[update test_google_calendar block_day unblock_day]

    def show
      load_settings
    end

    def pending_property
      @habitation = pending_photo_habitations.find(params[:id])
    end

    def update
      Setting.set(
        "photography_schedule_url",
        scheduling_params[:photography_schedule_url].to_s.strip,
        "URL externa para agendamento de fotos na captação"
      )
      Setting.set(
        "photography_google_calendar_enabled",
        scheduling_params[:photography_google_calendar_enabled].present? ? "1" : "0",
        "Habilita agendamento de fotos pelo Google Agenda"
      )
      Setting.set(
        "photography_google_calendar_id",
        scheduling_params[:photography_google_calendar_id].to_s.strip,
        "ID da agenda Google usada para fotografias"
      )
      Setting.set(
        "photography_google_credentials_path",
        scheduling_params[:photography_google_credentials_path].to_s.strip,
        "Caminho absoluto do JSON da conta de serviço Google Calendar"
      )

      redirect_to admin_scheduling_integration_path, notice: "Configuração de agendamento salva com sucesso."
    end

    def test_google_calendar
      result = GoogleCalendar::PhotographyEventService.test_connection
      if result.success?
        redirect_to admin_scheduling_integration_path, notice: "Conexão com Google Agenda validada com sucesso."
      else
        redirect_to admin_scheduling_integration_path, alert: "Falha ao validar Google Agenda: #{result.error_message}"
      end
    end

    def block_day
      block = PhotographyScheduleBlock.new(block_day_params)
      block.created_by = current_admin_user

      if block.save
        redirect_to admin_scheduling_integration_path, notice: "Dia bloqueado na agenda de fotografia."
      else
        load_settings
        @block_day_error = block.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    def unblock_day
      PhotographyScheduleBlock.find(params[:id]).destroy
      redirect_to admin_scheduling_integration_path, notice: "Bloqueio removido da agenda."
    end

    private

    def authorize_view!
      return if can?(:view, :agenda_fotografia) || can?(:manage, :agenda_fotografia) || can?(:manage, :integracoes)

      check_permission!(:view, :agenda_fotografia)
    end

    def authorize_manage!
      return if can?(:manage, :agenda_fotografia) || can?(:manage, :integracoes)

      check_permission!(:manage, :agenda_fotografia)
    end

    def load_settings
      @photography_schedule_url = Setting.get("photography_schedule_url", "")
      @photography_google_calendar_enabled = Habitation.google_photography_calendar_enabled?
      @photography_google_calendar_id = Habitation.google_photography_calendar_id
      @photography_google_credentials_path = Habitation.google_photography_credentials_path
      @photography_google_calendar_configured = Habitation.google_photography_calendar_configured?
      @blocked_days = PhotographyScheduleBlock.order(date: :asc)
      @pending_photo_habitations = pending_photo_habitations
    end

    def scheduling_params
      params.require(:scheduling).permit(
        :photography_schedule_url,
        :photography_google_calendar_enabled,
        :photography_google_calendar_id,
        :photography_google_credentials_path
      )
    end

    def block_day_params
      params.require(:photography_schedule_block).permit(:date, :reason)
    end

    def pending_photo_habitations
      scheduled_ids = Habitation.broker_intakes.where(photo_flow_choice: %w[schedule google_calendar]).select(:id)
      without_photo_ids = Habitation
        .broker_intakes
        .left_joins(:photos_attachments)
        .where(active_storage_attachments: { id: nil })
        .select(:id)

      Habitation
        .where(id: scheduled_ids)
        .or(Habitation.where(id: without_photo_ids))
        .where.not(intake_status: "published")
        .includes(:admin_user)
        .order(Arel.sql("photo_session_requested_at ASC NULLS LAST"), created_at: :desc)
        .limit(80)
    end
  end
end

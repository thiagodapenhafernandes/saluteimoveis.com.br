module Admin
  class WhatsappIntegrationsController < Admin::BaseController
    before_action -> { check_permission!(:manage, :integracoes) }
    before_action :load_config

    def show
    end

    def update
      Whatsapp::SiteRouting.update!(whatsapp_params)
      redirect_to admin_whatsapp_integration_path, notice: "Configurações de WhatsApp salvas com sucesso."
    rescue => e
      redirect_to admin_whatsapp_integration_path, alert: "Erro ao salvar WhatsApp: #{e.message}"
    end

    private

    def load_config
      @whatsapp_config = Whatsapp::SiteRouting.config
      @negotiation_types = Whatsapp::SiteRouting::NEGOTIATION_TYPES
    end

    def whatsapp_params
      params.require(:whatsapp).permit(
        :default_number,
        rules: @negotiation_types.keys.index_with { %i[number capture_enabled] }
      )
    end
  end
end

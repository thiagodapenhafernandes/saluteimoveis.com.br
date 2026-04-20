# frozen_string_literal: true

# Base para todos os controllers sob /field (PWA de corretores).
# - Hub (home, lista, etc) sempre acessível pra corretor logado.
# - Check-in específico exige FieldFeatureGate.field_checkin_enabled?.
module Field
  class BaseController < ApplicationController
    include FieldFeatureGate

    before_action :authenticate_admin_user!
    layout "field"

    private

    # Exigido pelas rotas de check-in/pings/manual (não pela home).
    def ensure_field_agent!
      return if current_admin_user&.field_agent_enabled?

      if request.format.json?
        render json: { error: "not_a_field_agent" }, status: :forbidden
      else
        redirect_to field_root_path, alert: "Você não está habilitado como corretor de campo."
      end
    end
  end
end

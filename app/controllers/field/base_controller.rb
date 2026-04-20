# frozen_string_literal: true

# Base para todos os controllers sob /field (PWA de corretores em campo).
# Autenticação Devise + gate de feature flag + verificação de field_agent_enabled.
module Field
  class BaseController < ApplicationController
    include FieldFeatureGate

    before_action :ensure_field_enabled!
    before_action :authenticate_admin_user!
    before_action :ensure_field_agent!

    layout "field"

    private

    def ensure_field_agent!
      return if current_admin_user&.field_agent_enabled?

      if request.format.json?
        render json: { error: "not_a_field_agent" }, status: :forbidden
      else
        redirect_to root_path, alert: "Você não está habilitado como corretor de campo."
      end
    end
  end
end

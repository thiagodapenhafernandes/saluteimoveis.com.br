# frozen_string_literal: true

# Base para todos os controllers sob /field (PWA de corretores em campo).
# Gate de feature flag + autenticação Devise vêm aqui. Subclasses adicionam
# suas próprias validações específicas.
module Field
  class BaseController < ApplicationController
    include FieldFeatureGate

    before_action :ensure_field_enabled!

    layout "field"
  end
end

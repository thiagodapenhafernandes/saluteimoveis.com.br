class WebhookService
  include HTTParty
  
  TIMEOUT = 5 # segundos
  MAX_RETRIES = 3
  
  class << self
    # Envia dados de formulário para o webhook configurado
    # @param origin_form [String] Identificador do formulário (ex: 'contact_form')
    # @param data [Hash] Dados do formulário
    # @param options [Hash] Opções adicionais (ex: :url para override)
    # @return [Boolean] true se enviado com sucesso
    def send_form_data(origin_form, data, options = {})
      # If specific URL is provided (e.g. testing), just use that
      if options[:url].present?
        payload = build_payload(origin_form, data)
        return send_with_retry(options[:url], payload)
      end

      active_settings = WebhookSetting.active
      return false if active_settings.empty?

      results = active_settings.map do |setting|
        # Prioritize WhatsApp URL if present (legacy behavior preservation)
        # or maybe we should send to both if both exist?
        # The previous code was: target_url = whatsapp_webhook_url.presence || webhook_url
        # This implies "use WhatsApp URL if set, otherwise standard URL".
        # I will keep this logic for now.
        target_url = setting.whatsapp_webhook_url.presence || setting.webhook_url
        next false if target_url.blank?

        payload = build_payload(origin_form, data)
        send_with_retry(target_url, payload)
      end
      
      results.any?
    end
    
    private
    
    def build_payload(origin_form, data)
      {
        origin_form: origin_form,
        timestamp: Time.current.iso8601,
        data: sanitize_data(data)
      }
    end
    
    def sanitize_data(data)
      # Remove dados sensíveis do Rails
      data.except('authenticity_token', 'commit', 'controller', 'action', 'utf8')
    end
    
    def send_with_retry(url, payload, attempt = 1)
      response = HTTParty.post(
        url,
        body: payload.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => 'Salute-Imoveis-Webhook/1.0'
        },
        timeout: TIMEOUT
      )
      
      if response.success?
        Rails.logger.info "Webhook sent successfully to #{url} (origin: #{payload[:origin_form]})"
        true
      else
        Rails.logger.warn "Webhook failed with status #{response.code} (attempt #{attempt}/#{MAX_RETRIES})"
        retry_if_needed(url, payload, attempt)
      end
    rescue StandardError => e
      Rails.logger.error "Webhook error: #{e.message} (attempt #{attempt}/#{MAX_RETRIES})"
      retry_if_needed(url, payload, attempt)
    end
    
    def retry_if_needed(url, payload, attempt)
      if attempt < MAX_RETRIES
        sleep(attempt) # Exponential backoff
        send_with_retry(url, payload, attempt + 1)
      else
        Rails.logger.error "Webhook failed after #{MAX_RETRIES} attempts"
        false
      end
    end
  end
end

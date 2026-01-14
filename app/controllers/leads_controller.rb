class LeadsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] # Para facilitar testes AJAX se necessário, mas idealmente usar CSRF

  def create
    @lead = Lead.new(lead_params)
    @lead.source_url = request.referer
    
    if @lead.save
      # Disparar Webhook
      # Disparar Webhook para todos os endpoints configurados
      WebhookService.send_form_data('whatsapp_lead', @lead.attributes.merge(
        property_title: Habitation.find_by(id: @lead.property_id)&.display_title
      ))

      # Send Emails (Async)
      LeadMailer.with(lead: @lead).new_lead_notification.deliver_later
      LeadMailer.with(lead: @lead).welcome_lead.deliver_later

      render json: { 
        success: true, 
        whatsapp_url: @lead.whatsapp_url 
      }
    else
      render json: { 
        success: false, 
        errors: @lead.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  private

  def lead_params
    params.require(:lead).permit(:name, :email, :phone, :property_id, :lead_type)
  end
end

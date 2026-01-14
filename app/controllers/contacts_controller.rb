class ContactsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def new
    # Página de contato (pode ser renderizada pelo HomeController#contato)
  end
  
  def create
    # Enviar webhook
    WebhookService.send_form_data('contact_form', contact_params.to_h)
    
    # Aqui você pode adicionar lógica para enviar email, salvar no banco, etc.
    
    redirect_to root_path, notice: 'Mensagem enviada com sucesso! Entraremos em contato em breve.'
  end
  
  private
  
  def contact_params
    params.require(:contact).permit(:name, :email, :phone, :message, :subject)
  end
end

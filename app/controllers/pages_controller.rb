class PagesController < ApplicationController
  def trabalhe_conosco
    @page_name = 'trabalhe_conosco'
    # Página "Trabalhe Conosco" / "Seja um Corretor Parceiro"
  end
  
  def submit_trabalhe_conosco
    # Enviar webhook
    WebhookService.send_form_data('work_with_us_form', work_params.to_h)
    
    redirect_to trabalhe_conosco_path, notice: 'Currículo enviado com sucesso! Entraremos em contato em breve.'
  end

  def simulador
    # Página "Simule um Financiamento"
  end

  def links_uteis
  end

  def corporativos
    @page_name = 'corporativos'
  end
  
  def privacy_policy
    # Política de Privacidade
  end
  
  def terms_of_use
    # Termos de Uso
  end
  
  private
  
  def work_params
    params.permit(:name, :email, :phone, :message, :creci, :experience, :cv)
  end
end

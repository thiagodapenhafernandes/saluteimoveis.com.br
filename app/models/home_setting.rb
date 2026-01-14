class HomeSetting < ApplicationRecord
  # ActiveStorage attachments
  has_one_attached :hero_background_desktop
  has_one_attached :hero_background_mobile
  
  # Validations
  validates :hero_title, presence: true
  validates :hero_subtitle, presence: true
  
  # Singleton pattern - só existe um registro
  def self.instance
    first_or_create!(
      hero_title: "Compre ou alugue na imobiliária mais amada de Balneário Camboriú.",
      hero_subtitle: "Aqui o lar é o centro das grandes histórias da vida.",
      cta_title: "Pronto para Encontrar Seu Imóvel?",
      cta_subtitle: "Entre em contato conosco e descubra as melhores oportunidades do mercado.",
      services_active: true,
      why_choose_active: true,
      cta_contact_active: true,
      overlay_opacity: 0.7,  # Opacidade padrão do overlay no hero
      hero_button_color: '#BFAB25', # Default brand accent
      hero_button_text_color: '#FFFFFF' # Default white text
    )
  end
end

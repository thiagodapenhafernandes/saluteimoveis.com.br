class Lead < ApplicationRecord
  enum :status, {
    novo: 'Novo',
    em_atendimento: 'Em Atendimento',
    concluido: 'Concluido',
    descartado: 'Descartado'
  }, default: :novo

  validates :name, :phone, presence: true
  
  # Optional: format validation for phone
  # validates :phone, format: { with: /\A\d{10,11}\z/, message: "deve ser um número válido com DDD" }

  def whatsapp_url
    # Use contact setting primary whatsapp or a default
    base_number = ContactSetting.first&.whatsapp_primary&.gsub(/\D/, '') || "554733111067"
    property = Habitation.find_by(id: property_id)
    
    message = if property
      "Olá, meu nome é #{name}. Estou interessado no imóvel #{property.display_title} (Código: #{property.codigo})."
    else
      "Olá, meu nome é #{name}. Gostaria de mais informações sobre os imóveis."
    end
    
    "https://wa.me/#{base_number}?text=#{ERB::Util.url_encode(message)}"
  end
end

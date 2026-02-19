class Lead < ApplicationRecord
  belongs_to :admin_user, optional: true
  belongs_to :distribution_rule, optional: true
  has_many :activities, class_name: "LeadActivity", dependent: :destroy
  
  after_create_commit :route_lead

  enum :status, {
    novo: 'Novo',
    em_atendimento: 'Em Atendimento',
    waiting_acceptance: 'Aguardando Aceite',
    represado: 'Represado',
    descartado: 'Descartado',
    concluido: 'Concluido'
  }, default: :novo

  scope :holding, -> { where(status: :represado) }
  scope :by_origin, ->(origin) { where(origin: origin) if origin.present? }

  validates :name, :phone, presence: true
  
  def display_name
    client_name.presence || name
  end

  def display_email
    client_email.presence || email
  end

  def display_phone
    client_phone.presence || phone
  end

  def whatsapp_url
    base_number = ContactSetting.first&.whatsapp_primary&.gsub(/\D/, '') || "554733111067"
    property = Habitation.find_by(id: property_id)
    
    message = if property
      "Olá, meu nome é #{display_name}. Estou interessado no imóvel #{property.codigo}. (Origem: #{origin})"
    else
      "Olá, meu nome é #{display_name}. Gostaria de mais informações. (Origem: #{origin})"
    end
    
    "https://wa.me/#{base_number}?text=#{ERB::Util.url_encode(message)}"
  end

  def direct_whatsapp_url
    number = display_phone&.gsub(/\D/, '')
    return nil if number.blank?
    
    # Ensure 55 prefix if not present and sounds like BR
    number = "55#{number}" if number.length <= 11
    
    "https://wa.me/#{number}"
  end

  def answer_for(key)
    return nil unless custom_answers.is_a?(Array)
    found = custom_answers.find { |item| item["key"].to_s == key.to_s }
    found ? found["answer"] : nil
  end

  def self.origin_options
    AttributeOption.where(context: "lead", category: "source").order(name: :asc).pluck(:name)
  end

  private

  def route_lead
    Leads::RoutingService.route!(self)
  end
end

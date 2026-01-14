class HomeSection < ApplicationRecord
  # Associations
  has_many :home_section_items, dependent: :destroy
  
  # Enum
  enum section_type: {
    services: 0,
    why_choose_us: 1,
    cta_contact: 2,
    featured_properties: 3,
    opportunities: 4,
    developments: 5,
    rentals: 6
  }
  
  # Validations
  validates :section_type, :title, presence: true
  
  # Scopes
  scope :active, -> { where(active: true).order(:order_position, :id) }
  scope :ordered, -> { order(:order_position, :id) }
end

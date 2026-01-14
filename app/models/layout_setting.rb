class LayoutSetting < ApplicationRecord
  has_one_attached :logo
  has_one_attached :favicon


  validates :primary_color, presence: true
  validates :secondary_color, presence: true
  validates :accent_color, presence: true

  def self.instance
    first_or_create!(
      primary_color: '#022B3A', # Default blue-three
      secondary_color: '#053C5E', # Default blue-one
      accent_color: '#BFAB25', # Default golden-one
      site_name: 'Salute Imóveis'
    )
  end
end

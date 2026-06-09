class PropertySetting < ApplicationRecord
  WATERMARK_POSITIONS = {
    "bottom_left" => "Inferior esquerdo",
    "bottom_right" => "Inferior direito",
    "center" => "Centro"
  }.freeze

  has_one_attached :watermark_image

  validates :watermark_position, presence: true, inclusion: { in: WATERMARK_POSITIONS.keys }

  def self.instance
    setting = first_or_initialize(watermark_position: "bottom_left")
    setting.watermark_position ||= "bottom_left"
    setting.save! if setting.new_record? || setting.changed?
    setting
  end

  def watermark_configured?
    watermark_image.attached?
  end
end

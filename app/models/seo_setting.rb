class SeoSetting < ApplicationRecord
  # ActiveStorage for OG image
  has_one_attached :og_image_file
  
  # Validations
  validates :page_name, presence: true, uniqueness: true
  validates :meta_title, presence: true
  
  # Find by page with caching
  def self.for_page(page_name)
    Rails.cache.fetch("seo_setting_#{page_name}", expires_in: 24.hours) do
      find_by(page_name: page_name) || new(page_name: page_name)
    end
  end

  # Clear cache after update
  after_commit :clear_seo_cache

  private

  def clear_seo_cache
    Rails.cache.delete("seo_setting_#{page_name}")
  end
end

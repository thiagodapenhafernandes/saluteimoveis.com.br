require "uri"

class SeoSetting < ApplicationRecord
  AI_STATUSES = %w[pending generating generated failed skipped].freeze

  # ActiveStorage for OG image
  has_one_attached :og_image_file
  
  # Validations
  validates :page_name, presence: true, uniqueness: true
  validates :canonical_key, presence: true, uniqueness: true
  validates :ai_status, inclusion: { in: AI_STATUSES }

  before_validation :ensure_canonical_key
  before_validation :sanitize_urls
  before_save :refresh_seo_score
  
  # Find by page with caching
  def self.for_page(page_name)
    Rails.cache.fetch("seo_setting_#{page_name}", expires_in: 24.hours) do
      find_by(page_name: page_name) || new(page_name: page_name)
    end
  end

  def self.for_canonical_key(canonical_key)
    find_by(canonical_key: canonical_key)
  end

  def public_applicable?
    active? && apply_to_public?
  end

  def robots_content
    "#{robots_index? ? "index" : "noindex"}, #{robots_follow? ? "follow" : "nofollow"}"
  end

  def score_label
    case seo_score.to_i
    when 85..100 then "Ótimo"
    when 70..84 then "Bom"
    when 50..69 then "Atenção"
    else "Fraco"
    end
  end

  def register_access!
    increment!(:access_count)
    update_column(:last_accessed_at, Time.current)
  end

  def display_name
    meta_title.presence || og_title.presence || page_name
  end

  def public_url(base_url)
    base = base_url.to_s.delete_suffix("/")
    path = sanitized_canonical_path.presence || canonical_path.presence || "/"
    path.start_with?("http") ? sanitize_url(path, base_url: base) : "#{base}#{path.start_with?("/") ? path : "/#{path}"}"
  end

  def social_image_url(base_url:, page_image: nil)
    base = base_url.to_s.delete_suffix("/")
    source = attached_og_image_path.presence ||
             page_image.presence ||
             related_habitation_image_url.presence ||
             "/icon.png"

    absolute_url(source, base)
  end

  def sanitized_canonical_path
    sanitize_path(canonical_path.presence || canonical_url)
  end

  # Clear cache after update
  after_commit :clear_seo_cache

  private

  def ensure_canonical_key
    self.canonical_key = page_name if canonical_key.blank?
  end

  def sanitize_urls
    sanitized_path = sanitized_canonical_path
    self.canonical_path = sanitized_path if sanitized_path.present?

    if canonical_url.present?
      self.canonical_url = sanitize_url(canonical_url, base_url: nil)
    elsif sanitized_path.present?
      self.canonical_url = sanitized_path
    end
  end

  def refresh_seo_score
    self.seo_score = Seo::Analyzer.new(self).score
  end

  def clear_seo_cache
    Rails.cache.delete("seo_setting_#{page_name}")
    Rails.cache.delete("seo_setting_#{canonical_key}")
  end

  def attached_og_image_path
    return unless og_image_file.attached?

    Rails.application.routes.url_helpers.rails_blob_path(og_image_file, only_path: true)
  end

  def related_habitation_image_url
    habitation = related_habitation
    return if habitation.blank?

    habitation.primary_image_url.presence || habitation.image_urls.first
  end

  def related_habitation
    identifier = canonical_key.to_s[/\Aproperty:(.+)\z/, 1].presence || path_identifier
    return if identifier.blank?

    Habitation.find_by(codigo: identifier) ||
      Habitation.find_by(id: identifier) ||
      Habitation.find_by(slug: identifier)
  end

  def path_identifier
    path = sanitized_canonical_path.to_s.split("?").first.to_s
    match_data = path.match(%r{\A/(?:imoveis|imovel)/([^/]+)\z})
    return if match_data.blank?

    URI.decode_www_form_component(match_data[1].to_s)
  rescue ArgumentError
    match_data&.[](1).to_s.presence
  end

  def absolute_url(source, base)
    source = source.to_s
    return source.sub("http://", "https://") if source.start_with?("http://")
    return source if source.start_with?("https://")

    "#{base}#{source.start_with?("/") ? source : "/#{source}"}"
  end

  def sanitize_url(value, base_url:)
    uri = URI.parse(value.to_s)
    path = sanitize_path("#{uri.path}#{uri.query.present? ? "?#{uri.query}" : ""}")
    return path if base_url.blank?

    "#{base_url}#{path}"
  rescue URI::InvalidURIError
    value.to_s
  end

  def sanitize_path(value)
    value = value.to_s
    return if value.blank?

    uri = URI.parse(value.start_with?("http") ? value : "https://example.com#{value.start_with?("/") ? value : "/#{value}"}")
    path = uri.path.presence || "/"
    pairs = URI.decode_www_form(uri.query.to_s)
               .filter_map do |key, val|
                 clean_key = key.to_s.delete_suffix("[]")
                 next if clean_key.match?(Seo::PageIdentity::IGNORED_PARAMS)
                 next if val.blank?

                 [clean_key, val.to_s.strip]
               end
               .sort

    query = pairs.any? ? "?#{URI.encode_www_form(pairs)}" : ""
    "#{path}#{query}"
  rescue URI::InvalidURIError
    value
  end
end

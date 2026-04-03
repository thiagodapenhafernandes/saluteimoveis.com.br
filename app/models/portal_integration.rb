class PortalIntegration < ApplicationRecord
  PORTAL_DEFINITIONS = {
    "zapimoveis" => { title: "ZapImóveis", feed_strategy: "vrsync_xml" },
    "vivareal_vrsync" => { title: "Viva Real VRSync", feed_strategy: "vrsync_xml" },
    "imovelweb" => { title: "Imovelweb", feed_strategy: "olx_json" },
    "chavesnamao" => { title: "Chaves na Mão", feed_strategy: "chaves_xml" },
    "casamineira" => { title: "Casa Mineira", feed_strategy: "vrsync_xml" },
    "lais_ai" => { title: "Lais Ai", feed_strategy: "vrsync_xml" },
    "netimoveis2" => { title: "Netimoveis 2", feed_strategy: "vrsync_xml" },
    "loft_portal" => { title: "Loft", feed_strategy: "vrsync_xml" }
  }.freeze

  PORTALS = PORTAL_DEFINITIONS.keys.freeze
  BUSINESS_TYPES = %w[venda aluguel].freeze

  validates :portal, presence: true, inclusion: { in: PORTALS }, uniqueness: true
  validates :allowed_business_types, presence: true
  validates :feed_token, presence: true, uniqueness: true

  has_many :portal_integration_events, primary_key: :portal, foreign_key: :portal, inverse_of: :portal_integration, dependent: :delete_all
  has_many :portal_listing_states, primary_key: :portal, foreign_key: :portal, inverse_of: :portal_integration, dependent: :delete_all

  before_validation :normalize_values
  before_validation :ensure_feed_token

  scope :enabled, -> { where(enabled: true) }

  def self.for_portal!(portal)
    normalized = portal.to_s.downcase
    raise ActiveRecord::RecordNotFound, "Portal inválido" unless PORTALS.include?(normalized)

    find_or_initialize_by(portal: normalized).tap do |config|
      if config.new_record?
        config.allowed_statuses = Habitation::STATUS_OPTIONS
        config.allowed_business_types = BUSINESS_TYPES
        config.require_exibir_no_site = true
        config.operational_status = "idle"
        config.save!
      end
    end
  end

  def masked_feed_token
    return nil if feed_token.blank?
    "********#{feed_token.to_s.last(4)}"
  end

  def masked_webhook_secret
    return nil if webhook_secret.blank?
    "********#{webhook_secret.to_s.last(4)}"
  end

  def title
    PORTAL_DEFINITIONS.dig(portal, :title) || portal.to_s.titleize
  end

  def feed_strategy
    PORTAL_DEFINITIONS.dig(portal, :feed_strategy) || "vrsync_xml"
  end

  def feed_format
    case feed_strategy
    when "olx_json" then :json
    else :xml
    end
  end

  private

  def normalize_values
    self.portal = portal.to_s.downcase.strip
    self.allowed_statuses = Array(allowed_statuses).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    self.allowed_business_types = Array(allowed_business_types).map(&:to_s).map(&:strip).reject(&:blank?).uniq & BUSINESS_TYPES

    self.allowed_statuses = Habitation::STATUS_OPTIONS if allowed_statuses.blank?
    self.allowed_business_types = BUSINESS_TYPES if allowed_business_types.blank?
    self.operational_status = operational_status.to_s.presence || "idle"
  end

  def ensure_feed_token
    return if feed_token.present?

    self.feed_token = loop do
      candidate = SecureRandom.hex(24)
      break candidate unless self.class.where.not(id: id).exists?(feed_token: candidate)
    end
  end
end

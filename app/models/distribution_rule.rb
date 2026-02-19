class DistributionRule < ApplicationRecord
  after_initialize :set_defaults

  has_many :distribution_rule_agents, dependent: :destroy
  has_many :admin_users, through: :distribution_rule_agents
  accepts_nested_attributes_for :distribution_rule_agents, allow_destroy: true

  enum :business_type, { venda: 0, locacao: 1, ambos: 2 }, suffix: true
  enum :distribution_mode, { rotary: 0, performance: 1, shark_tank: 2 }

  validates :name, presence: true
  validates :min_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :max_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validate :max_price_greater_than_min_price
  validates :pocket_time, numericality: { greater_than: 0 }, if: :pocket_active?

  scope :active, -> { where(active: true) }

  def next_available_agent
    if rotary?
      distribution_rule_agents.order(position: :asc, last_lead_received_at: :asc).first
    elsif performance?
      distribution_rule_agents.max_by { |dra| rand ** (1.0 / dra.weight) }
    else
      nil # Shark Tank doesn't have a "next" individual agent upfront
    end
  end

  def rotate_queue!(just_served_admin_user_id)
    return unless rotary?

    served = distribution_rule_agents.find_by(admin_user_id: just_served_admin_user_id)
    return unless served

    max_pos = distribution_rule_agents.maximum(:position) || 0
    served.update(position: max_pos + 1, last_lead_received_at: Time.current)
  end

  DAYS = %w[mon tue wed thu fri sat sun]

  def ensure_full_schedule
    self.represamento_schedule ||= {}
    DAYS.each do |day|
      self.represamento_schedule[day] ||= { "active" => "false", "start" => "09:00", "end" => "18:00" }
    end
  end

  private

  def set_defaults
    self.custom_filters ||= []
    self.meta_forms ||= []
    ensure_full_schedule
  end

  def max_price_greater_than_min_price
    return if min_price.blank? || max_price.blank?
    if max_price < min_price
      errors.add(:max_price, "deve ser maior ou igual ao preço mínimo")
    end
  end
end

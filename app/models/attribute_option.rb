class AttributeOption < ApplicationRecord
  CONTEXTS = %w[habitation lead].freeze
  CATEGORIES = %w[feature infrastructure unique_feature source status imediacoes sale_reason].freeze
  # Tipos de imóvel a que uma característica pode pertencer. Vazio = todos.
  PROPERTY_KINDS = %w[residencial comercial galpao terreno empreendimento].freeze

  before_validation :normalize_fields
  after_update_commit :sync_usage_on_rename, if: :saved_change_to_name?
  before_destroy :sync_usage_on_delete

  validates :name, :category, :context, presence: true
  validates :context, inclusion: { in: CONTEXTS }
  validates :category, inclusion: { in: CATEGORIES }
  validates :name, uniqueness: { scope: [:category, :context], case_sensitive: false, message: "já existe nesta categoria" }
  validate :context_immutable, on: :update
  validate :category_immutable, on: :update

  scope :for_context, ->(context) { where(context: context) if context.present? }
  scope :for_category, ->(category) { where(category: category) if category.present? }
  scope :search_name, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }
  # Card "Ajuste função criar características": características sem tipo vinculado
  # valem para todos; com tipo, só aparecem no tipo correspondente.
  scope :for_property_kind, ->(kind) {
    next all if kind.blank?

    where("property_kinds = '[]'::jsonb OR property_kinds @> ?", [kind.to_s].to_json)
  }

  def property_kinds
    Array(super).map(&:to_s).reject(&:blank?)
  end

  # Características sem tipo vinculado (valem para todos os tipos; a seleção final
  # ainda passa pela lista por tipo / whitelist).
  def self.unassigned_catalog_names(category)
    for_context("habitation").for_category(category).where("property_kinds = '[]'::jsonb").order(:name).pluck(:name)
  end

  # Características explicitamente vinculadas a um tipo de imóvel (entram sempre
  # naquele tipo, mesmo que não estejam na whitelist).
  def self.kind_catalog_names(category, property_kind)
    return [] if property_kind.blank?

    for_context("habitation").for_category(category)
      .where("property_kinds @> ?", [property_kind.to_s].to_json)
      .order(:name).pluck(:name)
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.context = context.to_s.strip
    self.category = category.to_s.strip
    self.name = AttributeOptions::HabitationFeatureNormalizer.label(name, category: category) if context == "habitation" && category.in?(%w[feature infrastructure])
    self.property_kinds = Array(property_kinds).map { |kind| kind.to_s.strip }.reject(&:blank?) & PROPERTY_KINDS
  end

  def context_immutable
    return unless will_save_change_to_context?
    errors.add(:context, "não pode ser alterado após a criação")
  end

  def category_immutable
    return unless will_save_change_to_category?
    errors.add(:category, "não pode ser alterada após a criação")
  end

  def sync_usage_on_rename
    AttributeOptions::SyncUsageService.new(
      context: context_before_last_save || context,
      category: category_before_last_save || category,
      old_name: name_before_last_save,
      new_name: name,
      action: :rename
    ).call
  end

  def sync_usage_on_delete
    AttributeOptions::SyncUsageService.new(
      context: context,
      category: category,
      old_name: name,
      action: :delete
    ).call
  end
end

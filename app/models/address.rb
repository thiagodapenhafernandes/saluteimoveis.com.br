class Address < ApplicationRecord
  STREET_TYPE_ALIASES = {
    "Avenida" => ["Avenida", "Av"],
    "Rua" => ["Rua", "R"],
    "Alameda" => ["Alameda", "Al"],
    "Travessa" => ["Travessa", "Tv", "Trav"],
    "Rodovia" => ["Rodovia", "Rod"],
    "Estrada" => ["Estrada", "Est", "Estr"],
    "Servidão" => ["Servidão", "Servidao", "Serv"],
    "Beco" => ["Beco"],
    "Praça" => ["Praça", "Praca", "Pç", "Pc"]
  }.freeze

  belongs_to :addressable, polymorphic: true
  before_validation :normalize_imediacoes
  before_validation :normalize_logradouro_type_prefix

  # Validations
  validates :logradouro, :bairro, :cidade, :uf, presence: true
  validates :uf, length: { is: 2 }
  validates :cep, format: { with: /\A\d{5}-?\d{3}\z/, message: "formato inválido (00000-000)" }, allow_blank: true
  
  # Geocoding (Placeholder for future implementation)
  # geocoded_by :full_address
  # after_validation :geocode, if: ->(obj){ obj.logradouro_changed? || obj.cidade_changed? }

  def full_address
    [logradouro, numero, bairro, cidade, uf, pais].compact.join(', ')
  end

  def self.normalize_street_type(value)
    normalized_value = normalize_street_token(value)
    return if normalized_value.blank?

    STREET_TYPE_ALIASES.find do |street_type, aliases|
      normalize_street_token(street_type) == normalized_value ||
        aliases.any? { |street_alias| normalize_street_token(street_alias) == normalized_value }
    end&.first
  end

  def self.extract_street_type(logradouro)
    street = logradouro.to_s.squish
    return [nil, nil] if street.blank?

    STREET_TYPE_ALIASES.each_key do |street_type|
      stripped = strip_street_type_prefix(street, street_type)
      return [street_type, stripped] if stripped != street
    end

    [nil, street]
  end

  def self.strip_street_type_prefix(logradouro, street_type)
    street = logradouro.to_s.squish
    aliases = aliases_for_street_type(street_type)
    return street if street.blank? || aliases.blank?

    street.sub(street_type_prefix_regex(aliases), "").squish
  end

  def imediacoes=(value)
    super(normalize_list_value(value))
  end

  def self.street_type_prefix_sql(expression)
    aliases = STREET_TYPE_ALIASES.values.flatten.map do |street_alias|
      Regexp.escape(I18n.transliterate(street_alias.to_s.downcase.delete(".")))
    end.uniq.join("|")

    "regexp_replace(unaccent(lower(COALESCE(#{expression}, ''))), '^\\s*(#{aliases})\\.?\\s+', '', 'i')"
  end

  private

  def normalize_logradouro_type_prefix
    self.tipo_endereco = self.class.normalize_street_type(tipo_endereco).presence || tipo_endereco.to_s.squish.presence
    self.logradouro = logradouro.to_s.squish.presence
    return if tipo_endereco.blank? || logradouro.blank?

    stripped = self.class.strip_street_type_prefix(logradouro, tipo_endereco)
    self.logradouro = stripped.presence || logradouro
  end

  def self.aliases_for_street_type(street_type)
    normalized_type = normalize_street_type(street_type)
    STREET_TYPE_ALIASES[normalized_type]
  end

  def self.street_type_prefix_regex(aliases)
    alternatives = aliases.sort_by(&:length).reverse.map do |street_alias|
      escaped = Regexp.escape(street_alias.to_s.delete("."))
      "#{escaped}\\.?"
    end

    /\A(?:#{alternatives.join("|")})\s+/i
  end

  def self.normalize_street_token(value)
    I18n.transliterate(value.to_s.downcase).delete(".").squish
  end

  def normalize_imediacoes
    self.imediacoes = normalize_list_value(imediacoes)
  end

  def normalize_list_value(value)
    raw_items =
      case value
      when Array
        value
      when String
        value.split(/[,\n;]+/)
      else
        Array(value)
      end

    raw_items.map { |item| item.to_s.strip }
             .reject(&:blank?)
             .uniq
  end
end

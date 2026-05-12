class HabitationDuplicateChecker
  Result = Struct.new(:complete, :matches, keyword_init: true) do
    def duplicate?
      matches.any?
    end
  end

  def initialize(street:, number:, building:, unit:, ignored_id: nil)
    @street = street
    @number = number
    @building = building
    @unit = unit
    @ignored_id = ignored_id
  end

  def call
    return Result.new(complete: false, matches: []) unless complete_identity?

    candidates = base_scope
      .where("#{normalized_sql("COALESCE(addresses.logradouro, habitations.endereco)")} = :street", street: normalize(@street))
      .where("#{normalized_sql("COALESCE(addresses.numero, habitations.numero)")} = :number", number: normalize(@number))
      .where("#{normalized_sql("habitations.nome_empreendimento")} = :building", building: normalize(@building))
      .limit(20)

    matches = candidates.select do |habitation|
      normalize_unit(habitation.bloco.presence || habitation.complemento) == normalize_unit(@unit)
    end

    Result.new(complete: true, matches: matches)
  end

  private

  def base_scope
    scope = Habitation.left_outer_joins(:address).includes(:address, :admin_user)
    @ignored_id.present? ? scope.where.not(id: @ignored_id) : scope
  end

  def complete_identity?
    [@street, @number, @building, @unit].all? { |value| normalize(value).present? }
  end

  def normalize(value)
    I18n.transliterate(value.to_s.downcase).gsub(/[^a-z0-9]+/, "")
  end

  def normalize_unit(value)
    normalize(value).sub(/\A(apartamento|apto|unidade|unid|un|bloco|bl|ap)/, "")
  end

  def normalized_sql(expression)
    "regexp_replace(unaccent(lower(COALESCE(#{expression}, ''))), '[^a-z0-9]+', '', 'g')"
  end
end

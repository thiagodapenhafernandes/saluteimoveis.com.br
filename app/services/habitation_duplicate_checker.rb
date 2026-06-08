class HabitationDuplicateChecker
  Result = Struct.new(:complete, :matches, keyword_init: true) do
    def duplicate?
      matches.any?
    end
  end

  def initialize(street:, number:, building:, unit:, status: nil, ignored_id: nil)
    @street = street
    @number = number
    @building = building
    @unit = unit
    @status = status
    @ignored_id = ignored_id
  end

  def call
    return Result.new(complete: false, matches: []) unless complete_identity?

    candidates = base_scope
      .where("#{normalized_sql("COALESCE(addresses.logradouro, habitations.endereco)")} = :street", street: normalize(@street))
      .where("#{normalized_sql("COALESCE(addresses.numero, habitations.numero)")} = :number", number: normalize(@number))
      .where(status: normalized_status)
      .where(exibir_no_site_flag: true)
      .where.not("habitations.status ~* ?", "suspenso|vendido|alugado")
      .limit(20)

    matches = candidates.select do |habitation|
      active_duplicate_candidate?(habitation) &&
        same_status?(habitation) &&
        same_optional_building?(habitation) &&
        same_optional_unit?(habitation)
    end

    Result.new(complete: true, matches: matches)
  end

  private

  def base_scope
    scope = Habitation.left_outer_joins(:address).includes(:address, :admin_user)
    if @ignored_id.present?
      scope = scope.where.not(id: @ignored_id)
      ignored_group_uuid = Habitation.where(id: @ignored_id).pick(:intake_group_uuid)
      if ignored_group_uuid.present?
        scope = scope.where("habitations.intake_group_uuid IS NULL OR habitations.intake_group_uuid != ?", ignored_group_uuid)
      end
    end
    scope
  end

  def complete_identity?
    [@street, @number].all? { |value| normalize(value).present? } && normalized_status.present?
  end

  def active_duplicate_candidate?(habitation)
    !habitation.inactive_for_admin_card?
  end

  def same_status?(habitation)
    Habitation.normalize_status(habitation.status).to_s == normalized_status
  end

  def same_optional_building?(habitation)
    expected = normalize(@building)
    actual = normalize(habitation.nome_empreendimento)

    expected.present? ? actual == expected : actual.blank?
  end

  def same_optional_unit?(habitation)
    expected = normalize_unit(@unit)
    actual = normalize_unit(habitation.bloco.presence || habitation.complemento)

    expected.present? ? actual == expected : actual.blank?
  end

  def normalized_status
    @normalized_status ||= Habitation.normalize_status(@status).to_s
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

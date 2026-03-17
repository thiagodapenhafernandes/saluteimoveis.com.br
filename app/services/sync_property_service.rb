class SyncPropertyService
  VISTA_KEY  = ENV.fetch('VISTA_KEY')  { 'ea83a702a7669520304be011258289fd' }
  VISTA_HOST = ENV.fetch('VISTA_HOST') { 'http://saluteim20174-rest.vistahost.com.br' }
  DETALHES_PATH = '/imoveis/detalhes'

  def initialize(codigo)
    @codigo = codigo
  end

  def perform
    habitation = Habitation.find_or_initialize_by(codigo: @codigo)
    hb = fetch_details(@codigo)
    
    unless hb
      habitation.update(last_sync_at: Time.current, last_sync_status: 'error', last_sync_message: "Imóvel não encontrado na API") if habitation.persisted?
      return { success: false, error: "Imóvel não encontrado na API" }
    end

    habitation_attrs, address_attrs = map_vista_payload(hb)
    habitation_attrs = habitation_attrs.merge(
      last_sync_at: Time.current,
      last_sync_status: 'success',
      last_sync_message: "Sincronizado com sucesso"
    )

    Habitation.transaction do
      habitation.assign_attributes(habitation_attrs)
      habitation.save!

      address = habitation.address || habitation.build_address
      address.assign_attributes(address_attrs)
      address.save!
    end

    sync_dynamic_attribute_options!(
      feature_values: habitation_attrs[:caracteristicas]&.values,
      infrastructure_values: habitation_attrs[:infra_estrutura],
      unique_feature_values: habitation_attrs[:caracteristica_unica],
      imediacoes_values: address_attrs[:imediacoes]
    )

    { success: true, habitation: habitation }
  rescue ActiveRecord::RecordInvalid => e
    error_msg = e.record.errors.full_messages.join(", ")
    habitation.update(last_sync_at: Time.current, last_sync_status: 'error', last_sync_message: error_msg) if habitation&.persisted?
    { success: false, error: error_msg }
  rescue => e
    habitation.update(last_sync_at: Time.current, last_sync_status: 'error', last_sync_message: e.message) if habitation && habitation.persisted?
    { success: false, error: e.message }
  end

  private

  def fetch_details(codigo)
    payload = {
      'fields' => [
        'TipoEndereco', 'Endereco', 'Numero', 'Bairro', 'BairroComercial', 'Cidade', 'UF', 'CEP', 'Complemento', 'Pais', 'Imediacoes',
        'Latitude', 'Longitude', 'TituloSite', 'Dormitorios', 'Suites', 'TotalBanheiros', 'Vagas',
        'AreaPrivativa', 'AreaTotal', 'Status', 'Situacao', 'ValorVenda', 'ValorLocacao',
        'ValorCondominio', 'ValorIptu', 'Empreendimento', 'CodigoEmpreendimento', 'Lancamento',
        'DescricaoWeb', 'CaracteristicaUnica', 'Caracteristicas', 'InfraEstrutura', 'ExibirNoSite', 'DestaqueWeb', 'Categoria', 'Construtora',
        'Proprietario', 'NomeProprietario', 'CodigoProprietario', 'EmailProprietario', 'CelularProprietario',
        'DataAtualizacao', 'DataEntrega', { 'Foto' => ['Foto', 'FotoPequena', 'Destaque', 'Ordem'] }
      ]
    }

    url = "#{VISTA_HOST}#{DETALHES_PATH}"
    params = {
      key: VISTA_KEY,
      imovel: codigo,
      pesquisa: payload.to_json
    }
    
    response = RestClient.get(url, params: params, accept: :json)
    JSON.parse(response.body)
  rescue => e
    nil
  end

  def map_vista_payload(hb)
    categoria = hb['Categoria'].to_s.strip
    tipo = categoria.casecmp("Empreendimento").zero? ? "Empreendimento" : "Unitário"
    constructor_id = resolve_constructor(hb['Construtora'])
    proprietor = resolve_proprietor(hb)
    raw_imediacoes = hb['Imediacoes']

    habitation_attrs = {
      titulo_anuncio: hb['TituloSite'],
      categoria: categoria.presence,
      tipo: tipo,
      status: hb['Status'],
      situacao: hb['Situacao'],
      endereco: hb['Endereco'],
      numero: hb['Numero'],
      bairro: hb['Bairro'],
      cidade: hb['Cidade'],
      uf: hb['UF'],
      cep: hb['CEP'],
      dormitorios_qtd: hb['Dormitorios'].to_i,
      suites_qtd: hb['Suites'].to_i,
      banheiros_qtd: hb['TotalBanheiros'].to_i,
      vagas_qtd: hb['Vagas'].to_i,
      area_privativa_m2: hb['AreaPrivativa'].to_f,
      area_total_m2: hb['AreaTotal'].to_f,
      valor_venda_cents: parse_money(hb['ValorVenda']),
      valor_locacao_cents: parse_money(hb['ValorLocacao']),
      valor_condominio_cents: parse_money(hb['ValorCondominio']),
      valor_iptu_cents: parse_money(hb['ValorIptu']),
      caracteristica_unica: normalize_csv_list(hb['CaracteristicaUnica']),
      caracteristicas: extract_characteristics(hb),
      infra_estrutura: extract_infrastructure(hb),
      codigo_empreendimento: hb['CodigoEmpreendimento'].to_s.strip.presence,
      nome_empreendimento: hb['Empreendimento'].to_s.strip.presence,
      construtora: hb['Construtora'].to_s.strip.presence,
      constructor_id: constructor_id,
      proprietor_id: proprietor&.id,
      proprietario: proprietor&.name,
      proprietario_codigo: proprietor&.vista_code,
      proprietario_email: proprietor&.email,
      proprietario_celular: proprietor&.mobile_phone,
      exibir_no_site_flag: hb['ExibirNoSite'] == 'Sim',
      destaque_web_flag: hb['DestaqueWeb'] == 'Sim',
      lancamento_flag: hb['Lancamento'] == 'Sim',
      data_atualizacao_crm: (Time.zone.parse(hb['DataAtualizacao']) rescue Time.current),
      pictures: format_photos(hb['Foto'])
    }

    address_attrs = {
      tipo_endereco: hb['TipoEndereco'],
      logradouro: hb['Endereco'],
      numero: hb['Numero'],
      complemento: hb['Complemento'],
      bairro: hb['Bairro'],
      bairro_comercial: hb['BairroComercial'],
      cidade: hb['Cidade'],
      uf: hb['UF'],
      cep: hb['CEP'],
      pais: hb['Pais'].presence || "Brasil",
      latitude: hb['Latitude'],
      longitude: hb['Longitude'],
      imediacoes: normalize_imediacoes(raw_imediacoes)
    }

    [habitation_attrs, address_attrs]
  end

  def parse_money(v)
    return nil if v.blank?
    clean = v.to_s.gsub(/[^\d.,]/, '').tr(',', '.')
    (clean.to_f * 100).to_i
  end

  def format_photos(photos_data)
    return [] if photos_data.blank?
    photos_array = photos_data.is_a?(Hash) ? photos_data.values : Array(photos_data)
    
    photos_array.map.with_index do |photo, index|
      next unless photo.is_a?(Hash)
      {
        url: photo['Foto'],
        url_pequena: photo['FotoPequena'],
        principal: photo['Destaque'] == 'Sim',
        ordem: photo['Ordem']&.to_i || index + 1
      }
    end.compact
  end

  def normalize_imediacoes(raw_value)
    case raw_value
    when Array
      raw_value
    when String
      raw_value.split(/[,\n;]+/)
    else
      Array(raw_value)
    end.map { |item| item.to_s.strip }.reject(&:blank?).uniq
  end

  def resolve_constructor(name)
    normalized_name = name.to_s.strip
    return nil if normalized_name.blank?

    constructor = Constructor.where("lower(name) = lower(?)", normalized_name).first
    constructor ||= Constructor.create!(name: normalized_name)
    constructor.id
  rescue
    nil
  end

  def resolve_proprietor(hb)
    proprietor_name = hb['NomeProprietario'].presence || hb['Proprietario'].presence || hb['Construtora'].presence
    proprietor_code = hb['CodigoProprietario'].to_s.strip.presence
    proprietor_email = hb['EmailProprietario'].to_s.strip.presence
    proprietor_phone = hb['CelularProprietario'].to_s.strip.presence
    return nil if proprietor_name.to_s.strip.blank?

    role = hb['NomeProprietario'].present? || hb['Proprietario'].present? ? :owner : :developer

    proprietor = nil
    proprietor = Proprietor.find_by(vista_code: proprietor_code) if proprietor_code.present?
    proprietor ||= Proprietor.find_by(email: proprietor_email) if proprietor_email.present?
    proprietor ||= Proprietor.where("lower(name) = lower(?)", proprietor_name.to_s.strip).first
    proprietor ||= Proprietor.new

    proprietor.name = proprietor_name.to_s.strip
    proprietor.role = role
    proprietor.vista_code = proprietor_code if proprietor_code.present?
    proprietor.email = proprietor_email if proprietor_email.present?
    proprietor.mobile_phone = proprietor_phone if proprietor_phone.present?
    proprietor.save!
    proprietor
  rescue
    nil
  end

  def extract_characteristics(data)
    return {} unless data['Caracteristicas'].is_a?(Hash)

    data['Caracteristicas'].each_with_object({}) do |(key, value), acc|
      next unless value.to_s.casecmp("sim").zero?

      label = key.to_s.strip
      next if label.blank?

      acc[label] = label
    end
  end

  def extract_infrastructure(data)
    return [] unless data['InfraEstrutura'].is_a?(Hash)

    data['InfraEstrutura'].each_with_object([]) do |(key, value), acc|
      label = key.to_s.strip
      acc << label if value.to_s.casecmp("sim").zero? && label.present?
    end.uniq
  end

  def normalize_csv_list(value)
    case value
    when Array
      value
    when String
      value.split(/[,\n;]+/)
    else
      Array(value)
    end.map { |item| item.to_s.strip }.reject(&:blank?).uniq
  end

  def sync_dynamic_attribute_options!(feature_values:, infrastructure_values:, unique_feature_values:, imediacoes_values:)
    now = Time.current
    rows = []
    rows.concat(build_attribute_rows(feature_values, "feature", now))
    rows.concat(build_attribute_rows(infrastructure_values, "infrastructure", now))
    rows.concat(build_attribute_rows(unique_feature_values, "unique_feature", now))
    rows.concat(build_attribute_rows(imediacoes_values, "imediacoes", now))
    return if rows.empty?

    AttributeOption.insert_all(rows, unique_by: :index_attribute_options_on_context_category_lower_name)
  rescue
    nil
  end

  def build_attribute_rows(values, category, now)
    normalize_csv_list(values).map do |name|
      { context: "habitation", category: category, name: name, created_at: now, updated_at: now }
    end
  end
end

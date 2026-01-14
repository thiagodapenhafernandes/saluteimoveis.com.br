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

    attrs = map_vista_to_habitation(hb)
    attrs = attrs.merge(last_sync_at: Time.current, last_sync_status: 'success', last_sync_message: "Sincronizado com sucesso")
    
    if habitation.update(attrs)
      { success: true, habitation: habitation }
    else
      error_msg = habitation.errors.full_messages.join(", ")
      habitation.update(last_sync_at: Time.current, last_sync_status: 'error', last_sync_message: error_msg) if habitation.persisted?
      { success: false, error: error_msg }
    end
  rescue => e
    habitation.update(last_sync_at: Time.current, last_sync_status: 'error', last_sync_message: e.message) if habitation && habitation.persisted?
    { success: false, error: e.message }
  end

  private

  def fetch_details(codigo)
    payload = {
      'fields' => [
        'TipoEndereco', 'Endereco', 'Numero', 'Bairro', 'Cidade', 'UF', 'CEP', 'Complemento',
        'Latitude', 'Longitude', 'TituloSite', 'Dormitorios', 'Suites', 'TotalBanheiros', 'Vagas',
        'AreaPrivativa', 'AreaTotal', 'Status', 'Situacao', 'ValorVenda', 'ValorLocacao',
        'ValorCondominio', 'ValorIptu', 'Empreendimento', 'CodigoEmpreendimento', 'Lancamento',
        'DescricaoWeb', 'CaracteristicaUnica', 'ExibirNoSite', 'DestaqueWeb', 'Categoria',
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

  def map_vista_to_habitation(hb)
    # Simplified mapping for common fields
    {
      titulo_anuncio: hb['TituloSite'],
      categoria: hb['Categoria'],
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
      caracteristica_unica: hb['CaracteristicaUnica'],
      exibir_no_site_flag: hb['ExibirNoSite'] == 'Sim',
      destaque_web_flag: hb['DestaqueWeb'] == 'Sim',
      lancamento_flag: hb['Lancamento'] == 'Sim',
      data_atualizacao_crm: Time.zone.parse(hb['DataAtualizacao']) rescue Time.current,
      pictures: format_photos(hb['Foto'])
    }
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
end

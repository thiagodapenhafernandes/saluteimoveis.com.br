# lib/tasks/builder_fields.thor
require File.expand_path('config/environment.rb')
require 'rest-client'
require 'thor'
require 'cgi'
require 'uri'
require 'securerandom'
require 'set'

class BuilderFields < Thor::Group
  class_option :strict, type: :boolean, default: false,
               desc: "Quando true, respeita validacoes do model. Por padrao ignora validacoes."
  class_option :progress_id, type: :string, default: nil,
               desc: "UUID para acompanhar com rake 'vista:progress[UUID]'."
  class_option :progress, type: :boolean, default: false,
               desc: "Exibe progresso no console e gera UUID automaticamente."
  class_option :force, type: :boolean, default: false,
               desc: "Compatibilidade com o comando usado no v2."

  desc "building fields from Vista API"

  VISTA_KEY  = ENV.fetch('VISTA_KEY')  { 'ea83a702a7669520304be011258289fd' }
  VISTA_HOST = ENV.fetch('VISTA_HOST') { 'http://saluteim20174-rest.vistahost.com.br' }

  LISTAR_PATH   = '/imoveis/listar'
  DETALHES_PATH = '/imoveis/detalhes'

  HEADERS = { accept: 'application/json' }.freeze
  TIMEOUT = 20
  MAX_RETRIES = 4
  PROGRESS_TTL = 6.hours

  def initialize(args = [], options = {}, config = {})
    super
    opts = self.options || {}
    @progress_enabled = opts[:progress] || opts[:progress_id].present? || ENV['VISTA_PROGRESS_ID'].present?
    @progress_id = opts[:progress_id].presence || ENV['VISTA_PROGRESS_ID'] || SecureRandom.uuid
    @stats = { total: 0, created: 0, updated: 0, failed: 0 }
    @progress_state = {}
    @strict_mode = opts[:strict].to_s == 'true'
  end

  def pre_cleanup
    count = Habitation.where(imovel_dwv: 'Sim').delete_all
    say_status :info, "Removidos #{count} imoveis com imovel_dwv='Sim' (para reimportar).", :yellow
  end

  def export
    start_progress! if @progress_enabled

    pagina = 1
    total_importados = 0
    total_paginas = nil

    loop do
      listing = fetch_list(pagina)
      break unless listing.present?

      total_paginas ||= listing['paginas'].to_i
      total_paginas = 1 if total_paginas.zero?
      update_progress(total_pages: total_paginas, current_page: pagina) if @progress_enabled

      itens = listing.except('total', 'paginas', 'pagina', 'quantidade').values
      page_size = itens.size

      say_status :info, "Pagina #{pagina}/#{total_paginas} - registros: #{page_size}", :blue
      update_progress(current_page_size: page_size) if @progress_enabled

      batch_attrs = []
      batch_codes = []

      itens.each do |item|
        codigo = item['Codigo'].to_s
        next if codigo.blank?

        begin
          details = fetch_details(codigo)
          next unless details

          attrs = build_params(item, details)
          batch_attrs << attrs
          batch_codes << attrs[:codigo]

          total_importados += 1
          @stats[:total] += 1

          if @progress_enabled
            update_progress(
              processed: total_importados,
              failed: @stats[:failed],
              last_codigo: codigo
            )
            emit_progress_line
          end
        rescue => e
          @stats[:failed] += 1
          if @progress_enabled
            update_progress(last_error: "#{e.class}: #{e.message}", last_codigo: codigo, failed: @stats[:failed])
            emit_progress_line
          end

          location = e.backtrace&.first.to_s
          method   = location.split("`").last&.gsub("'", "")
          say_status :error,
            "Erro processando codigo #{codigo}: #{e.class} - #{e.message} (em #{method} @ #{location})",
            :red
        end
      end

      if @strict_mode
        batch_attrs.each do |attrs|
          result = upsert_habitation(attrs)
          @stats[result] += 1 if result
        end
      elsif batch_attrs.any?
        existing = Habitation.where(codigo: batch_codes).pluck(:codigo).to_set
        Habitation.upsert_all(batch_attrs, unique_by: :index_habitations_on_codigo, record_timestamps: true)

        created = batch_codes.size - existing.size
        updated = existing.size
        @stats[:created] += created
        @stats[:updated] += updated
      end

      if @progress_enabled
        update_progress(
          created: @stats[:created],
          updated: @stats[:updated],
          failed: @stats[:failed]
        )
        emit_progress_line
      end

      break if pagina >= total_paginas
      pagina += 1
    end

    finish_progress!(total_importados) if @progress_enabled
    say_status :success, "Finalizado! Registros processados: #{total_importados}", :green
    RefreshFeaturedPropertiesJob.perform_later if defined?(RefreshFeaturedPropertiesJob)
  rescue => e
    update_progress(status: 'failed', last_error: "#{e.class}: #{e.message}") if @progress_enabled
    raise
  end

  def normalize_cep(v)
    s = v&.to_s&.gsub(/\D/, '')
    return nil if s.blank?
    s.length == 8 ? "#{s[0..4]}-#{s[5..7]}" : nil
  end

  no_tasks do
    def upsert_habitation(attrs)
      rec = Habitation.find_or_initialize_by(codigo: attrs[:codigo])
      is_new = rec.new_record?
      rec.assign_attributes(attrs)

      if @strict_mode
        rec.save!
      else
        rec.save(validate: false)
      end

      is_new ? :created : :updated
    end

    def fetch_list(pagina)
      list_payload = {
        'fields' => [],
        'order' => { 'Bairro' => 'asc' },
        'paginacao' => { 'pagina' => pagina, 'quantidade' => 50 }
      }

      fetch_json(
        LISTAR_PATH,
        params: {
          key: VISTA_KEY,
          pesquisa: list_payload.to_json,
          showtotal: 1,
          showSuspended: 1
        }
      )
    end

    def fetch_details(codigo)
      payload = {
        'fields' => [
          # Endereco
          'TipoEndereco', 'Endereco', 'Numero', 'Bairro', 'BairroComercial', 'Cidade',
          'UF', 'Pais', 'CEP', 'Complemento', 'Bloco', 'Lote', 'Imediacoes',
          'Latitude', 'Longitude', 'TituloSite',
          # Comodos/Caracteristicas
          'Dormitorios', 'Suites', 'TotalBanheiros', 'BanheiroSocialQtd', 'Vagas',
          'AreaPrivativa', 'AreaTotal', 'Decorado',
          # Valores & situacao
          'Status', 'Situacao', 'ValorVenda', 'ValorVendaAnterior', 'ValorLocacao',
          'ValorTotalAluguel', 'ValorPromocional', 'ValorCondominio', 'ValorIptu',
          # Empreendimento/Outros
          'Empreendimento', 'CodigoEmpreendimento', 'Lancamento', 'AptosAndar',
          'AptosEdificio', 'Garden', 'QuadraMar', 'SemMobilia',
          # Construtora/Proprietario
          'Construtora', 'CodigoProprietario', 'Proprietario',
          # Web/Descricoes
          'InscricaoImobiliaria', 'DescricaoEmpreendimento', 'DescricaoWeb',
          'Caracteristicas', 'InfraEstrutura', 'CaracteristicaUnica', 'Observacoes',
          # Destaques de localizacao
          '3Avenida', 'Arriba', 'AvenidaBrasil', 'BairroFazendaItajai', 'BalnearioPicarras',
          'Barra', 'BarraNorte', 'BarraSul', 'Cabecudas', 'Camboriu', 'Centro',
          'Estaleirinho', 'FrenteMarAvenidaAtlantica', 'Itajai', 'Itapema', 'Nacoes',
          'Pioneiros', 'PraiaBrava', 'PraiaDosAmores', 'QuadraMar', 'VistaFrenteMar',
          # Flags site
          'FestivalSalute', 'ExibirNoSite', 'ExibirNoSiteSalute', 'DestaqueWeb',
          # Config
          'Categoria', 'CategoriaGrupo', 'DataAtualizacao', 'DataEntrega', 'TourVirtual',
          { 'Video' => ['Video', 'Tipo'] },
          { 'Foto' => ['Foto', 'FotoPequena', 'Destaque', 'Ordem'] },
          { 'FotoEmpreendimento' => ['Foto', 'FotoPequena', 'Destaque', 'Ordem'] },
          'CodigoCorretor', 'CaptadorAccountId', 'Agenciador',
          'CodigoDWV', 'ImovelDWV', 'TemPlaca'
        ]
      }

      fetch_json(
        DETALHES_PATH,
        params: {
          key: VISTA_KEY,
          imovel: codigo,
          showSuspended: 1,
          pesquisa: payload.to_json
        }
      )
    end

    def fetch_json(path, params:)
      url = URI.join(VISTA_HOST, path).to_s
      qs  = params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
      full = "#{url}?#{qs}"

      with_retries do
        resp = RestClient::Request.execute(
          method: :get,
          url: full,
          headers: HEADERS,
          timeout: TIMEOUT,
          open_timeout: TIMEOUT
        )
        JSON.parse(resp.body)
      end
    rescue RestClient::ExceptionWithResponse => e
      say_status :error, "HTTP #{e.http_code} em #{path}: #{e.message}", :red
      nil
    rescue JSON::ParserError => e
      say_status :error, "JSON invalido em #{path}: #{e.message}", :red
      nil
    end

    def with_retries
      tries = 0
      begin
        yield
      rescue RestClient::Exceptions::Timeout, RestClient::TooManyRequests, Errno::ECONNRESET => e
        tries += 1
        raise if tries > MAX_RETRIES
        sleep(0.5 * (2 ** (tries - 1)))
        retry
      end
    end

    def safe_int(v)
      v&.to_s&.gsub(/[^\d]/, '').presence&.to_i
    end

    def safe_float(v)
      s = v.to_s.tr(',', '.')
      s =~ /\d/ ? s.to_f : nil
    end

    def safe_bool(v)
      case v
      when true, 'Sim', 'True', 'true', 1, '1' then true
      when false, 'Nao', 'False', 'false', 0, '0', nil, '' then false
      else !!v
      end
    end

    def safe_date(v)
      return nil if v.blank?
      Time.zone.parse(v.to_s) rescue nil
    end

    def parse_money_to_cents(v)
      return nil if v.blank?
      clean = v.to_s.gsub(/[^\d.,]/, '').tr(',', '.')
      (clean.to_f * 100).to_i
    end

    def sanitize_html(text)
      ActionView::Base.full_sanitizer.sanitize(text.to_s)
    end

    def format_photos(photos_data)
      return [] if photos_data.blank?

      photos_array =
        if photos_data.is_a?(Hash)
          photos_data.values
        elsif photos_data.is_a?(Array)
          photos_data.map { |a| a.is_a?(Array) ? a[1] : a }
        else
          []
        end

      photos_array.map.with_index do |photo, index|
        next unless photo.is_a?(Hash)

        url = photo['Foto'] || photo['url'] || photo['Url']
        next if url.blank?

        {
          url: url,
          url_pequena: photo['FotoPequena'],
          descricao: photo['Descricao'],
          principal: (photo['Destaque'] == 'Sim' || photo['Principal'] == true),
          ordem: photo['Ordem']&.to_i || index + 1
        }
      end.compact
    end

    def format_videos(video_data)
      return [] if video_data.blank?

      Array(video_data).map do |item|
        entry = item.is_a?(Array) ? item[1] : item
        next unless entry.is_a?(Hash)

        {
          url: entry['Video'],
          tipo: entry['Tipo']
        }
      end.compact
    end

    def normalize_characteristic_name(name)
      name.to_s
          .downcase
          .unicode_normalize(:nfkd)
          .encode('ASCII', replace: '')
          .gsub(/\s+/, '_')
          .gsub(/[^a-z0-9_]/, '')
    end

    def extract_characteristics(data)
      return {} unless data['Caracteristicas'].is_a?(Hash)

      chars = {}
      data['Caracteristicas'].each do |key, value|
        next unless value.to_s.downcase == 'sim'

        normalized = normalize_characteristic_name(key)
        chars[normalized] = normalized
      end

      chars
    end

    def extract_infrastructure(data)
      return [] unless data['InfraEstrutura'].is_a?(Hash)

      data['InfraEstrutura'].each_with_object([]) do |(key, value), acc|
        acc << key if value.to_s.downcase == 'sim'
      end
    end

    def characteristic_true?(data, *keys)
      return false unless data['Caracteristicas'].is_a?(Hash)

      keys.any? { |key| data['Caracteristicas'][key].to_s.downcase == 'sim' }
    end

    def build_params(list_item, hb)
      photos = format_photos(hb['Foto'])
      photos_emp = format_photos(hb['FotoEmpreendimento'])
      videos = format_videos(hb['Video'])

      valor_venda_cents = parse_money_to_cents(hb['ValorVenda'])
      area_total = safe_float(hb['AreaTotal'])
      valor_por_m2 = (valor_venda_cents && area_total && area_total > 0) ? (valor_venda_cents / area_total).round : nil

      {
        slug: build_slug(hb),
        codigo: hb['Codigo'].to_s,
        categoria: hb['Categoria'],
        tipo: hb['Categoria'],
        status: hb['Status'],
        situacao: hb['Situacao'],
        codigo_empreendimento: hb['CodigoEmpreendimento'],
        nome_empreendimento: hb['Empreendimento'],

        tipo_endereco: hb['TipoEndereco'],
        endereco: hb['Endereco'],
        numero: hb['Numero'],
        complemento: hb['Complemento'],
        bairro: hb['Bairro'],
        bairro_comercial: hb['BairroComercial'],
        bloco: hb['Bloco'],
        lote: hb['Lote'],
        imediacoes: hb['Imediacoes'],
        cidade: hb['Cidade'],
        uf: hb['UF'],
        cep: normalize_cep(hb['CEP']),
        pais: hb['Pais'].presence || 'Brasil',
        latitude: hb['Latitude'],
        longitude: hb['Longitude'],

        dormitorios_qtd: safe_int(hb['Dormitorios']),
        suites_qtd: safe_int(hb['Suites']),
        banheiros_qtd: safe_int(hb['TotalBanheiros']),
        banheiro_social_qtd: safe_int(hb['BanheiroSocialQtd']),
        vagas_qtd: safe_int(hb['Vagas']),
        area_privativa_m2: safe_float(hb['AreaPrivativa']),
        area_total_m2: area_total,

        aptos_andar: safe_int(hb['AptosAndar']),
        aptos_edificio: safe_int(hb['AptosEdificio']),

        valor_venda_cents: valor_venda_cents,
        valor_venda_anterior_cents: parse_money_to_cents(hb['ValorVendaAnterior']),
        valor_locacao_cents: parse_money_to_cents(hb['ValorLocacao']),
        valor_total_aluguel_cents: parse_money_to_cents(hb['ValorTotalAluguel']),
        valor_promocional_cents: parse_money_to_cents(hb['ValorPromocional']),
        valor_condominio_cents: parse_money_to_cents(hb['ValorCondominio']),
        valor_iptu_cents: parse_money_to_cents(hb['ValorIptu']),
        valor_por_m2_cents: valor_por_m2,

        construtora: hb['Construtora'],
        proprietario: hb['Proprietario'],
        proprietario_codigo: hb['CodigoProprietario'],
        inscricao_imobiliaria: hb['InscricaoImobiliaria'],

        descricao_empreendimento: sanitize_html(hb['DescricaoEmpreendimento']),
        descricao_web: sanitize_html(hb['DescricaoWeb']),
        descricao_interna: nil,
        titulo_anuncio: hb['TituloSite'],
        observacoes: sanitize_html(hb['Observacoes']),

        caracteristicas: extract_characteristics(hb),
        infra_estrutura: extract_infrastructure(hb),
        caracteristica_unica: hb['CaracteristicaUnica'],

        destaque_localizacao: {
          "3_avenida": hb['3Avenida'],
          "arriba": hb['Arriba'],
          "avenida_brasil": hb['AvenidaBrasil'],
          "bairro_fazenda_itajai": hb['BairroFazendaItajai'],
          "balneario_picarras": hb['BalnearioPicarras'],
          "barra": hb['Barra'],
          "barra_norte": hb['BarraNorte'],
          "barra_sul": hb['BarraSul'],
          "cabecudas": hb['Cabecudas'],
          "camboriu": hb['Camboriu'],
          "centro": hb['Centro'],
          "estaleirinho": hb['Estaleirinho'],
          "frente_mar_avenida_atlantica": hb['FrenteMarAvenidaAtlantica'],
          "itajai": hb['Itajai'],
          "itapema": hb['Itapema'],
          "nacoes": hb['Nacoes'],
          "pioneiros": hb['Pioneiros'],
          "praia_brava": hb['PraiaBrava'],
          "praia_dos_amores": hb['PraiaDosAmores'],
          "quadra_mar": hb['QuadraMar'],
          "vista_frente_mar": hb['VistaFrenteMar']
        },

        pictures: photos,
        fotos_empreendimento: photos_emp,
        videos: videos,

        exibir_no_site_flag: safe_bool(hb['ExibirNoSite']),
        exibir_no_site_salute_flag: safe_bool(hb['ExibirNoSiteSalute']),
        destaque_web_flag: safe_bool(hb['DestaqueWeb']),
        lancamento_flag: safe_bool(hb['Lancamento']),
        aceita_permuta_flag: characteristic_true?(hb, 'AceitaPermuta', 'Aceita Permuta'),
        aceita_financiamento_flag: characteristic_true?(hb, 'AceitaFinanciamento', 'Aceita Financiamento'),
        mobiliado_flag: characteristic_true?(hb, 'Mobiliado'),
        decorado_flag: safe_bool(hb['Decorado']),
        garden_flag: safe_bool(hb['Garden']),
        quadra_mar_flag: safe_bool(hb['QuadraMar']),
        sem_mobilia_flag: safe_bool(hb['SemMobilia']) || safe_bool(list_item['SemMobilia']),
        festival_salute_flag: safe_bool(hb['FestivalSalute']),
        tem_placa_flag: safe_bool(hb['TemPlaca']),
        piscina_flag: characteristic_true?(hb, 'Piscina'),
        lavabo_flag: characteristic_true?(hb, 'Lavabo'),
        varanda_gourmet_flag: characteristic_true?(hb, 'Varanda Gourmet', 'VarandaGourmet'),

        terceira_avenida_flag: safe_bool(hb['3Avenida']),
        arriba_flag: safe_bool(hb['Arriba']),
        avenida_brasil_flag: safe_bool(hb['AvenidaBrasil']),
        bairro_fazenda_itajai_flag: safe_bool(hb['BairroFazendaItajai']),
        balneario_picarras_flag: safe_bool(hb['BalnearioPicarras']),
        barra_flag: safe_bool(hb['Barra']),
        barra_norte_flag: safe_bool(hb['BarraNorte']),
        barra_sul_flag: safe_bool(hb['BarraSul']),
        cabecudas_flag: safe_bool(hb['Cabecudas']),
        camboriu_flag: safe_bool(hb['Camboriu']),
        centro_flag: safe_bool(hb['Centro']),
        estaleirinho_flag: safe_bool(hb['Estaleirinho']),
        frente_mar_avenida_atlantica_flag: safe_bool(hb['FrenteMarAvenidaAtlantica']),
        itajai_flag: safe_bool(hb['Itajai']),
        itapema_flag: safe_bool(hb['Itapema']),
        nacoes_flag: safe_bool(hb['Nacoes']),
        pioneiros_flag: safe_bool(hb['Pioneiros']),
        praia_brava_flag: safe_bool(hb['PraiaBrava']),
        praia_dos_amores_flag: safe_bool(hb['PraiaDosAmores']),
        vista_frente_mar_flag: safe_bool(hb['VistaFrenteMar']),

        categoria_grupo: hb['CategoriaGrupo'],
        data_entrega: safe_date(hb['DataEntrega']),
        tour_virtual: hb['TourVirtual'],

        data_atualizacao_crm: safe_date(hb['DataAtualizacao']) || Time.current,
        data_cadastro_crm: nil,

        codigo_corretor: hb['CodigoCorretor'],
        captador_account_id: hb['CaptadorAccountId'],
        agenciador: hb['Agenciador'],

        codigo_dwv: hb['CodigoDWV'],
        imovel_dwv: hb['ImovelDWV'],
        status_vista: hb['Status']
      }
    end

    def build_slug(hb)
      parts = [hb['Categoria'], hb['Cidade'], hb['Bairro'], hb['Codigo']].compact
      parts.join('-').parameterize
    end

    def start_progress!
      say_status :info, "Progress ID: #{@progress_id}", :yellow
      say_status :info, "Acompanhar: bundle exec rake 'vista:progress[#{@progress_id}]'", :yellow
      @progress_state = {
        progress_id: @progress_id,
        status: 'running',
        started_at: Time.current,
        total_pages: 0,
        current_page: 0,
        processed: 0,
        created: 0,
        updated: 0,
        failed: 0
      }
      write_progress(@progress_state)
    end

    def finish_progress!(total_importados)
      update_progress(
        status: 'done',
        finished_at: Time.current,
        processed: total_importados,
        created: @stats[:created],
        updated: @stats[:updated],
        failed: @stats[:failed]
      )
    end

    def update_progress(payload)
      @progress_state = @progress_state.merge(payload).merge(updated_at: Time.current)
      write_progress(@progress_state)
    end

    def emit_progress_line
      total_pages = @progress_state[:total_pages].to_i
      current_page = @progress_state[:current_page].to_i
      processed = @progress_state[:processed].to_i
      created = @progress_state[:created].to_i
      updated = @progress_state[:updated].to_i
      failed = @progress_state[:failed].to_i
      last_codigo = @progress_state[:last_codigo]

      page_label = total_pages.positive? ? "#{current_page}/#{total_pages}" : current_page.to_s
      line = "Progresso: pagina #{page_label} | processados #{processed} | criados #{created} | atualizados #{updated} | falhas #{failed}"
      line += " | ultimo #{last_codigo}" if last_codigo.present?
      say_status :info, line, :blue
    end

    def progress_key
      "vista:import:#{@progress_id}"
    end

    def write_progress(payload)
      Rails.cache.write(progress_key, payload, expires_in: PROGRESS_TTL)
    end

    def read_progress
      Rails.cache.read(progress_key)
    end
  end
end

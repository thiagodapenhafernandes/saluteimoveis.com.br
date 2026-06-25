require "builder"

module Portal
  # Chaves na Mão XML — formato proprietário
  # Spec: https://tecnologiacnm.github.io/cnm-xml-documentation/arquivo/especificacoes/especificacoes-tags.html
  # Tags em PT-BR (referencia, transacao, finalidade, tipo, valor, etc.)
  # Lido 1x por dia pelo portal.
  class ChavesXmlSerializer
    DEFAULT_APP_HOST = "https://saluteimoveis.com.br"
    EMPTY_TAGS = %i[
      transacao2 finalidade2 tipo2 valor_locacao valor_iptu valor_condominio
      area_total area_util conservacao quartos suites garagem banheiro closet
      salas despensa bar cozinha quarto_empregada escritorio area_servico
      lareira varanda lavanderia aceita_pet estado cidade bairro cep endereco
      numero complemento esconder_endereco_imovel data_atualizacao latitude
      longitude video tour_360 aceita_troca periodo_locacao
    ].freeze

    def initialize(habitations:, integration:)
      @habitations = habitations
      @integration = integration
    end

    def to_xml
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct! :xml, version: "1.0", encoding: "UTF-8"

      xml.Document do
        xml.imoveis do
          @habitations.each do |habitation|
            xml.Imovel { add_property!(xml, habitation) }
          end
        end
      end

      xml.target!
    end

    private

    def add_property!(xml, habitation)
      values = property_values(habitation)

      tag(xml, :referencia, values[:referencia])
      tag(xml, :codigo_cliente, values[:codigo_cliente])
      tag(xml, :link_cliente, values[:link_cliente])
      tag(xml, :titulo, values[:titulo])
      tag(xml, :transacao, values[:transacao])
      tag(xml, :transacao2, values[:transacao2])
      tag(xml, :finalidade, values[:finalidade])
      tag(xml, :finalidade2, values[:finalidade2])
      tag(xml, :destaque, values[:destaque])
      tag(xml, :tipo, values[:tipo])
      tag(xml, :tipo2, values[:tipo2])
      tag(xml, :valor, values[:valor])
      tag(xml, :valor_locacao, values[:valor_locacao])
      tag(xml, :valor_iptu, values[:valor_iptu])
      tag(xml, :valor_condominio, values[:valor_condominio])
      tag(xml, :area_total, values[:area_total])
      tag(xml, :area_util, values[:area_util])
      tag(xml, :conservacao, values[:conservacao])
      tag(xml, :quartos, values[:quartos])
      tag(xml, :suites, values[:suites])
      tag(xml, :garagem, values[:garagem])
      tag(xml, :banheiro, values[:banheiro])
      tag(xml, :closet, values[:closet])
      tag(xml, :salas, values[:salas])
      tag(xml, :despensa, values[:despensa])
      tag(xml, :bar, values[:bar])
      tag(xml, :cozinha, values[:cozinha])
      tag(xml, :quarto_empregada, values[:quarto_empregada])
      tag(xml, :escritorio, values[:escritorio])
      tag(xml, :area_servico, values[:area_servico])
      tag(xml, :lareira, values[:lareira])
      tag(xml, :varanda, values[:varanda])
      tag(xml, :lavanderia, values[:lavanderia])
      tag(xml, :aceita_pet, values[:aceita_pet])
      tag(xml, :estado, values[:estado])
      tag(xml, :cidade, values[:cidade])
      tag(xml, :bairro, values[:bairro])
      tag(xml, :cep, values[:cep])
      tag(xml, :endereco, values[:endereco])
      tag(xml, :numero, values[:numero])
      tag(xml, :complemento, values[:complemento])
      tag(xml, :esconder_endereco_imovel, values[:esconder_endereco_imovel])
      xml.descritivo { xml.cdata!(values[:descritivo].to_s.first(3000)) }
      add_photos!(xml, habitation)
      tag(xml, :data_atualizacao, values[:data_atualizacao])
      tag(xml, :latitude, values[:latitude])
      tag(xml, :longitude, values[:longitude])
      tag(xml, :video, values[:video])
      tag(xml, :tour_360, values[:tour_360])
      add_feature_list!(xml, :area_comum, common_area_features_for(habitation))
      add_feature_list!(xml, :area_privativa, private_area_features_for(habitation))
      tag(xml, :aceita_troca, values[:aceita_troca])
      tag(xml, :periodo_locacao, values[:periodo_locacao])
    end

    def property_values(habitation)
      {
        referencia: habitation.codigo.to_s,
        codigo_cliente: habitation.codigo.to_s,
        link_cliente: property_url_for(habitation),
        titulo: title_for(habitation),
        transacao: transacao_for(habitation),
        transacao2: secondary_transaction_for(habitation),
        finalidade: finalidade_for(habitation),
        finalidade2: "",
        destaque: destaque_for(habitation),
        tipo: tipo_for(habitation),
        tipo2: "",
        valor: valor_for(habitation),
        valor_locacao: secondary_rent_value_for(habitation),
        valor_iptu: money_or_blank(habitation.valor_iptu_cents),
        valor_condominio: money_or_blank(habitation.valor_condominio_cents),
        area_total: decimal_or_blank(habitation.area_total_m2),
        area_util: decimal_or_blank(habitation.area_privativa_m2),
        conservacao: "",
        quartos: integer_or_blank(habitation.dormitorios_qtd),
        suites: integer_or_blank(habitation.suites_qtd),
        garagem: integer_or_blank(habitation.vagas_qtd),
        banheiro: integer_or_blank(habitation.banheiros_qtd),
        closet: "",
        salas: integer_or_blank(habitation.try(:salas_qtd)),
        despensa: "",
        bar: "",
        cozinha: "",
        quarto_empregada: "",
        escritorio: "",
        area_servico: "",
        lareira: "",
        varanda: "",
        lavanderia: "",
        aceita_pet: "",
        estado: habitation.uf.to_s.upcase,
        cidade: habitation.cidade.to_s,
        bairro: habitation.bairro.to_s,
        cep: sanitize_cep(habitation.cep),
        endereco: habitation.endereco.to_s,
        numero: habitation.numero.to_s,
        complemento: habitation.complemento.to_s,
        esconder_endereco_imovel: "0",
        descritivo: description_for(habitation),
        data_atualizacao: datetime_for(habitation.updated_at),
        latitude: coordinate(habitation, :latitude),
        longitude: coordinate(habitation, :longitude),
        video: habitation.try(:video_url).presence || habitation.try(:video).presence,
        tour_360: habitation.try(:tour_virtual).presence,
        aceita_troca: aceita_troca_for(habitation),
        periodo_locacao: periodo_locacao_for(habitation)
      }.reverse_merge(EMPTY_TAGS.index_with(""))
    end

    def transacao_for(habitation)
      # V = Venda, L = Locação. Venda tem precedência se ambos.
      habitation.valor_venda_cents.to_i.positive? ? "V" : "L"
    end

    def secondary_transaction_for(habitation)
      return "L" if habitation.valor_venda_cents.to_i.positive? && habitation.valor_locacao_cents.to_i.positive?

      ""
    end

    def finalidade_for(habitation)
      # RE = residencial, CO = comercial, RU = rural
      category = habitation.categoria.to_s.downcase
      case category
      when /chácara|chacara|sítio|sitio|fazenda|rural/ then "RU"
      when /comercial|sala|conjunto|loja|ponto|prédio comercial|predio comercial|galpão|galpao|industrial|escritório|escritorio/
        "CO"
      else
        "RE"
      end
    end

    def tipo_for(habitation)
      # Tipo do imóvel — texto livre que faz sentido para o portal
      habitation.categoria.presence || "Imóvel"
    end

    def valor_for(habitation)
      # Valor principal (venda se houver, senão locação)
      cents = habitation.valor_venda_cents.to_i.positive? ? habitation.valor_venda_cents : habitation.valor_locacao_cents
      format_money(cents)
    end

    def secondary_rent_value_for(habitation)
      return "" unless secondary_transaction_for(habitation).present?

      format_money(habitation.valor_locacao_cents)
    end

    def destaque_for(habitation)
      explicit = habitation.respond_to?(:destaque_chaves_na_mao) ? habitation.destaque_chaves_na_mao : nil
      return "1" if explicit.to_s.casecmp("sim").zero?
      return "0" if explicit.to_s.casecmp("nao").zero? || explicit.to_s.casecmp("não").zero?
      habitation.destaque_web_flag ? "1" : "0"
    end

    def description_for(habitation)
      habitation.descricao_web.to_plain_text.presence ||
        habitation.meta_description.to_plain_text.presence ||
        "Sem descrição"
    rescue
      "Sem descrição"
    end

    def common_area_features_for(habitation)
      Array(habitation.infra_estrutura).map { |v| v.to_s.strip }.reject(&:blank?).uniq.first(40)
    end

    def private_area_features_for(habitation)
      values = []
      values.concat(Array(habitation.caracteristicas&.values)) if habitation.caracteristicas.respond_to?(:values)
      values.concat(Array(habitation.unique_features)) if habitation.respond_to?(:unique_features)
      values.map { |v| v.to_s.strip }.reject(&:blank?).uniq.first(40)
    end

    def add_photos!(xml, habitation)
      xml.fotos_imovel do
        image_urls_for(habitation).first(30).each do |url|
          xml.foto do
            tag(xml, :url, url)
            tag(xml, :data_atualizacao, datetime_for(habitation.updated_at))
          end
        end
      end
    end

    def add_feature_list!(xml, tag_name, features)
      xml.tag!(tag_name) do
        features.each { |feature| tag(xml, :item, feature) }
      end
    end

    def tag(xml, name, value = "")
      xml.tag!(name, value.to_s)
    end

    def title_for(habitation)
      habitation.titulo_anuncio.presence || "Imóvel #{habitation.codigo}"
    end

    def property_url_for(habitation)
      slug = habitation.slug.presence || habitation.to_param
      "#{app_host}/imoveis/#{slug}"
    end

    def image_urls_for(habitation)
      habitation.image_urls.filter_map { |url| absolute_url(url) }
    end

    def absolute_url(url)
      value = url.to_s.strip
      return nil if value.blank?
      return value if value.match?(%r{\Ahttps?://}i)

      path = value.start_with?("/") ? value : "/#{value}"
      "#{app_host}#{path}"
    end

    def app_host
      ENV.fetch("APP_HOST", DEFAULT_APP_HOST).to_s.sub(%r{/*\z}, "")
    end

    def format_money(cents)
      # Reais com 2 casas decimais e ponto como separador (spec: "valor com ponto (.) para casas decimais")
      format("%.2f", cents.to_i / 100.0)
    end

    def money_or_blank(cents)
      return "" unless cents.to_i.positive?

      format_money(cents)
    end

    def format_decimal(value)
      format("%.2f", value.to_f)
    end

    def decimal_or_blank(value)
      return "" unless value.to_f.positive?

      format_decimal(value)
    end

    def integer_or_blank(value)
      integer = value.to_i
      integer.positive? ? integer.to_s : ""
    end

    def sanitize_cep(cep)
      cep.to_s.gsub(/\D/, "")
    end

    def coordinate(habitation, kind)
      source = habitation.address || habitation
      value = source.respond_to?(kind) ? source.send(kind) : nil
      return nil if value.blank?
      number = value.to_f
      return nil if number.zero?
      number
    end

    def datetime_for(value)
      (value || Time.current).strftime("%Y-%m-%d %H:%M:%S")
    end

    def aceita_troca_for(habitation)
      return "1" if habitation.try(:aceita_permuta_flag?)
      return "1" if habitation.try(:aceita_permuta_veiculo_flag?)
      return "1" if habitation.try(:aceita_permuta_imovel_flag?)
      return "1" if habitation.try(:aceita_permuta_outros_flag?)

      "0"
    end

    def periodo_locacao_for(habitation)
      return "" unless transacao_for(habitation) == "L" || secondary_transaction_for(habitation) == "L"

      case habitation.try(:periodo_locacao_chaves_na_mao).to_s
      when "por_mes" then "1"
      when "por_dia" then "2"
      when "por_ano" then "3"
      when "por_semana" then "4"
      else ""
      end
    end
  end
end

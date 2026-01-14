# == Schema Information
#
# Table name: habitations
#
class Habitation < ApplicationRecord
  # Concerns organizados por responsabilidade
  include Habitation::PriceFormatting
  include Habitation::SearchScopes
  include Habitation::CacheableMethods
  include Habitation::SeoHelpers
  
  # FriendlyId para URLs amigáveis (SEO)
  extend FriendlyId
  friendly_id :slug_candidates, use: [:slugged, :finders]
  
  # Paginação
  self.per_page = 12
  
  # Associations
  belongs_to :empreendimento, 
    class_name: 'Habitation',
    primary_key: 'codigo',
    foreign_key: 'codigo_empreendimento',
    optional: true
  
  has_many :units, 
    class_name: 'Habitation',
    primary_key: 'codigo',
    foreign_key: 'codigo_empreendimento'
  
  # Active Storage Photos (For manual upload)
  has_many_attached :photos
  
  # ActionText for Rich Text
  has_rich_text :descricao_web
  has_rich_text :meta_description

  # Validations
  validates :codigo, presence: true, uniqueness: true
  validates :categoria, presence: true
  
  # Callbacks
  after_save :clear_cache
  after_destroy :clear_cache
  
  # Slug candidates para FriendlyId (ordem de prioridade)
  def slug_candidates
    [
      [:tipo_imovel_slug, :cidade_slug, :bairro_slug, :codigo],
      [:tipo_imovel_slug, :cidade_slug, :codigo],
      [:categoria, :codigo]
    ]
  end
  
  # Métodos auxiliares para o slug
  def tipo_imovel_slug
    categoria&.parameterize
  end
  
  def cidade_slug
    cidade&.parameterize
  end
  
  def bairro_slug
    bairro&.parameterize
  end

  def preco_principal
    if valor_venda_cents.to_i > 0
      ActiveSupport::NumberHelper.number_to_currency(valor_venda_cents / 100.0)
    elsif valor_locacao_cents.to_i > 0
      "#{ActiveSupport::NumberHelper.number_to_currency(valor_locacao_cents / 100.0)}/mês"
    else
      "Sob Consulta"
    end
  end

  def tipo_transacao
    if status.to_s.downcase.include?('locacao') || status.to_s.downcase.include?('aluguel')
      'Locação'
    else
      'Venda'
    end
  end
  
  # Retorna a URL da imagem principal
  def primary_image_url
    img = primary_image
    return nil unless img
    img.is_a?(Hash) ? img['url'] : img
  end

  # Retorna lista de URLs de todas as imagens
  def image_urls
    all_images.map do |img|
      img.is_a?(Hash) ? img['url'] : img
    end.compact
  end
  
  # Retorna a primeira imagem do imóvel (Hash format)
  def primary_image
    # Priority: Active Storage Photos -> API Pictures
    if photos.attached?
      return { 'url' => Rails.application.routes.url_helpers.url_for(ordered_photos.first) }
    end

    images = if empreendimento?
               fotos_empreendimento.present? ? fotos_empreendimento : pictures
             else
               pictures
             end
    
    return nil unless images.is_a?(Array) && images.any?
    
    pic = images.first
    pic.is_a?(Hash) ? pic : { 'url' => pic }
  end
  
  # Retorna todas as imagens (Hash format)
  def all_images
    attached_images = ordered_photos.map { |p| { 'url' => Rails.application.routes.url_helpers.url_for(p) } }
    
    images = if empreendimento?
               fotos_empreendimento.present? ? fotos_empreendimento : pictures
             else
               pictures
             end
    
    api_images = if images.is_a?(Array)
                   images.map { |pic| pic.is_a?(Hash) ? pic : { 'url' => pic } }
                 else
                   []
                 end
    
    attached_images + api_images
  end

  # Photo Sorting Logic
  def ordered_photo_ids=(ids)
    ids = ids.split(',') if ids.is_a?(String)
    # Ensure IDs are integers and unique, reject blanks
    self.photo_ids_order = ids.compact.map(&:to_i).uniq - [0]
  end

  def ordered_photos
    return photos unless photo_ids_order.present? && photos.attached?

    # Fetch all photos efficiently
    attached_photos = photos.includes(:blob)
    
    # Sort them in memory according to the ID list
    # Photos not in the list go to the end
    attached_photos.sort_by do |photo|
      idx = photo_ids_order.index(photo.id)
      idx || 999999 # Place unordered photos at the end
    end
  end

  # Dynamic Field Setters (Array handling)
  def imediacoes=(value)
    if value.is_a?(Array)
      super(value.reject(&:blank?).join(','))
    else
      super
    end
  end

  def meta_keywords=(value)
    if value.is_a?(Array)
      super(value.reject(&:blank?).join(','))
    else
      super
    end
  end
  
  # Verifica se é um empreendimento
  def empreendimento?
    tipo == 'Empreendimento'
  end
  
  # Verifica se é uma unidade de empreendimento
  def unidade?
    codigo_empreendimento.present?
  end
  
  # Retorna todas as unidades disponíveis deste empreendimento
  # Empreendimento tem 'codigo', unidades têm 'codigo_empreendimento'
  def development_units
    return Habitation.none unless empreendimento? && codigo.present?
    Habitation.active.where(codigo_empreendimento: codigo)
  end
  
  # Conta quantas unidades disponíveis esse empreendimento tem
  def available_units_count
    return 0 unless empreendimento?
    development_units.count
  end
  
  # Verifica se é um empreendimento com unidades
  def has_available_units?
    empreendimento? && available_units_count > 0
  end
  
  # Retorna o título para exibição
  def display_title
    titulo_anuncio.presence || default_title
  end
  
  # Título padrão baseado nas características
  def default_title
    parts = []
    parts << categoria if categoria.present?
    parts << "#{dormitorios_qtd} dormitórios" if dormitorios_qtd > 0
    parts << "em #{bairro}" if bairro.present?
    parts << cidade if cidade.present?
    parts.join(' ')
  end

  # Retorna lista de badges (etiquetas) para exibição no card
  def display_badges
    badges = []
    
    # Priority 1: Caracteristica Unica (Mapped labels from Vista)
    if caracteristica_unica.present?
      text = caracteristica_unica.upcase
      badges << { 
        text: text, 
        color: badge_color_for(text),
        tailwind_color: tailwind_color_for(text)
      }
    end
    
    # Priority 2: Lançamento Flag (Manual flag)
    if lancamento_flag && !caracteristica_unica.to_s.downcase.include?('lançamento')
      badges << { 
        text: 'LANÇAMENTO', 
        color: 'success',
        tailwind_color: 'orange-500'
      }
    end
    
    # Priority 3: Destaque Web (Featured)
    if destaque_web_flag
      badges << { 
        text: 'DESTAQUE', 
        color: 'warning text-dark',
        tailwind_color: 'yellow-500'
      }
    end
    
    badges.first(2)
  end

  def tailwind_color_for(text)
    t = text.to_s.upcase
    if t.include?('PLANTA') || t.include?('CONSTRUÇÃO') || t.include?('PRÉ-LANÇAMENTO')
      'primary-600'
    elsif t.include?('LANÇAMENTO')
      'orange-500'
    elsif t.include?('DESTAQUE') || t.include?('OPORTUNIDADE')
      'yellow-500'
    elsif t.include?('PRONTO')
      'green-600'
    else
      'primary-500'
    end
  end

  def badge_color_for(text)
    t = text.to_s.upcase
    if t.include?('PLANTA') || t.include?('CONSTRUÇÃO') || t.include?('PRÉ-LANÇAMENTO')
      'primary'
    elsif t.include?('LANÇAMENTO')
      'success'
    elsif t.include?('DESTAQUE') || t.include?('OPORTUNIDADE')
      'warning text-dark'
    elsif t.include?('PRONTO')
      'info'
    else
      'secondary'
    end
  end
  
  private
  
  def clear_cache
    Rails.cache.delete(cache_key)
    Rails.cache.delete([self.class.name, id])
    Rails.cache.delete("habitation_#{id}")
    
    # Limpar cache da view materializada se for um imóvel em destaque
    if destaque_web_flag_changed? || exibir_no_site_flag_changed?
      refresh_materialized_view
    end
  end
  
  def refresh_materialized_view
    # Atualizar a materialized view em background
    RefreshFeaturedPropertiesJob.perform_later if defined?(RefreshFeaturedPropertiesJob)
  end
end

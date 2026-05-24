module ApplicationHelper
  INTERNAL_ACTIVE_STORAGE_PATH = "/rails/active_storage/".freeze

  def optimized_image_source(source, resize_to_limit: nil, resize_to_fill: nil, saver: { quality: 82 })
    return if source.blank?

    image = if source.is_a?(Hash)
      source["attachment"] || source[:attachment] ||
        source["url_pequena"] || source[:url_pequena] ||
        source["url_small"] || source[:url_small] ||
        source["thumbnail_url"] || source[:thumbnail_url] ||
        source["url"] || source[:url]
    else
      source
    end
    return image unless image.respond_to?(:variant)
    return image unless active_storage_variants_enabled?

    transformations = {}
    transformations[:resize_to_limit] = resize_to_limit if resize_to_limit.present?
    transformations[:resize_to_fill] = resize_to_fill if resize_to_fill.present?
    transformations[:saver] = saver if saver.present?

    transformations.present? ? image.variant(transformations) : image
  end

  def active_storage_variants_enabled?
    ENV["ACTIVE_STORAGE_VARIANTS_ENABLED"] == "true"
  end

  def public_price_range_options(transaction_type = nil)
    if transaction_type.to_s.downcase.in?(%w[aluguel locacao locação alugar])
      [
        ["Todos os Valores", ""],
        ["até R$5.000", "0-5000"],
        ["R$5.000 ↔ R$10.000", "5000-10000"],
        ["R$10.000 ↔ R$15.000", "10000-15000"],
        ["R$15.000 ↔ R$20.000", "15000-20000"],
        ["R$20.000 ↔ R$25.000", "20000-25000"],
        ["Acima R$25.000", "25000-"]
      ]
    else
      [
        ["Todos os Valores", ""],
        ["até R$1.000.000", "0-1000000"],
        ["R$1.000.000 ↔ R$2.000.000", "1000000-2000000"],
        ["R$2.000.000 ↔ R$3.000.000", "2000000-3000000"],
        ["R$3.000.000 ↔ R$5.000.000", "3000000-5000000"],
        ["R$5.000.000 ↔ R$10.000.000", "5000000-10000000"],
        ["a partir de R$10.000.000", "10000000-"]
      ]
    end
  end

  def public_image_url(source, resize_to_limit: nil, resize_to_fill: nil, saver: { quality: 82 })
    return if source.blank?

    image = if resize_to_limit.present? || resize_to_fill.present?
              optimized_image_source(source, resize_to_limit: resize_to_limit, resize_to_fill: resize_to_fill, saver: saver)
            else
              image_source_from(source)
            end

    active_storage_public_path(image) || normalize_public_image_url(image)
  end

  # SEO Helper - Dynamic meta tags
  def seo_meta_tags(page_name = 'home')
    seo = SeoSetting.for_page(page_name)
    
    content_for :meta_tags do
      tags = []
      tags << tag.meta(name: 'title', content: seo.meta_title || 'Salute Imóveis')
      tags << tag.meta(name: 'description', content: seo.meta_description || 'Imobiliária em Balneário Camboriú')
      tags << tag.meta(name: 'keywords', content: seo.meta_keywords) if seo.meta_keywords.present?
      
      # Open Graph
      tags << tag.meta(property: 'og:title', content: seo.meta_title || 'Salute Imóveis')
      tags << tag.meta(property: 'og:description', content: seo.meta_description || 'Imobiliária em Balneário Camboriú')
      
      tags.join("\n").html_safe
    end
  end
  
  # Banner display helper
  def display_banner(position, options = {})
    banner = Banner.active.by_position(position).detect(&:displayable?)
    return if banner.blank?
    
    render 'shared/banner', banner: banner, options: options
  end

  # Sorting helper
  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = column == sort_column ? "current #{sort_direction}" : nil
    direction = column == sort_column && sort_direction == "asc" ? "desc" : "asc"
    
    # Merge existing params with new sort params
    link_to url_for(request.query_parameters.merge(sort: column, direction: direction)), class: "text-decoration-none text-dark fw-bold d-flex align-items-center gap-1 #{css_class}" do
      concat title
      if column == sort_column
        concat tag.i(class: "bi bi-sort-#{sort_direction == 'asc' ? 'up' : 'down'}")
      else
        concat tag.i(class: "bi bi-arrow-down-up text-muted opacity-50 small")
      end
    end
  end

  private

  def image_source_from(source)
    if source.respond_to?(:attached?)
      return source.attachment if source.attached?
      return
    end

    return source unless source.is_a?(Hash)

    source["attachment"] || source[:attachment] ||
      source["url"] || source[:url] ||
      source["url_pequena"] || source[:url_pequena] ||
      source["url_small"] || source[:url_small] ||
      source["thumbnail_url"] || source[:thumbnail_url]
  end

  def active_storage_public_path(image)
    return if image.blank?

    if image.respond_to?(:attached?)
      return unless image.attached?

      rails_blob_path(image.attachment, only_path: true)
    elsif defined?(ActiveStorage::VariantWithRecord) && image.is_a?(ActiveStorage::VariantWithRecord)
      rails_representation_path(image, only_path: true)
    elsif defined?(ActiveStorage::Variant) && image.is_a?(ActiveStorage::Variant)
      rails_representation_path(image, only_path: true)
    elsif defined?(ActiveStorage::Attachment) && image.is_a?(ActiveStorage::Attachment)
      rails_blob_path(image, only_path: true)
    elsif defined?(ActiveStorage::Blob) && image.is_a?(ActiveStorage::Blob)
      rails_blob_path(image, only_path: true)
    end
  rescue StandardError
    nil
  end

  def normalize_public_image_url(image)
    value = image.to_s
    return value if value.blank?
    return value if value.start_with?("/", "data:", "blob:")

    uri = URI.parse(value)
    return value unless uri.path.start_with?(INTERNAL_ACTIVE_STORAGE_PATH)

    [uri.path, uri.query.presence && "?#{uri.query}"].compact.join
  rescue URI::InvalidURIError
    value
  end
end

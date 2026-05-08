module ApplicationHelper
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

    transformations = {}
    transformations[:resize_to_limit] = resize_to_limit if resize_to_limit.present?
    transformations[:resize_to_fill] = resize_to_fill if resize_to_fill.present?
    transformations[:saver] = saver if saver.present?

    transformations.present? ? image.variant(transformations) : image
  end

  def public_image_url(source)
    return if source.blank?

    image = source.is_a?(Hash) ? (source["url"] || source[:url] || source["attachment"] || source[:attachment]) : source
    image.respond_to?(:variant) ? url_for(image) : image
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
end

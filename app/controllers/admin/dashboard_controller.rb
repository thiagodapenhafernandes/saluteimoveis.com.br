class Admin::DashboardController < Admin::BaseController
  def index
    # Properties Stats
    @properties_count = Habitation.active.count
    @featured_count = Habitation.featured.count
    @for_sale_count = Habitation.active.where("status IN (?)", ['Venda', 'Venda e Aluguel']).count
    @for_rent_count = Habitation.active.where("status IN (?)", ['Aluguel', 'Venda e Aluguel']).count
    @developments_count = Habitation.where(tipo: 'Empreendimento').count
    
    # Recent Properties
    @recent_properties = Habitation.newest_first.limit(8)
    
    # Values
    @total_sale_value = Habitation.active.where("valor_venda_cents > 0").sum(:valor_venda_cents) / 100.0
    @avg_sale_value = Habitation.active.where("valor_venda_cents > 0").average(:valor_venda_cents).to_f / 100.0
    
    # Other Stats
    @banners_count = Banner.count
    @active_banners = Banner.active.count
    @seo_pages_count = SeoSetting.count
    @home_sections_count = HomeSection.count
    @active_sections_count = HomeSection.active.count
    
    # Cities with most properties
    @top_cities = Habitation.active
      .group(:cidade)
      .order('count_id DESC')
      .limit(5)
      .count('id')

    # Leads Stats
    @total_leads = Lead.count
    @new_leads = Lead.where(status: ['Novo', nil]).count
    @leads_last_7_days = Lead.where('created_at >= ?', 7.days.ago).count
    @leads_last_30_days = Lead.where('created_at >= ?', 30.days.ago).count

    # Top neighborhoods by interest (leads)
    # We join with Habitation to get neighborhood name if property_id present
    @top_neighborhoods = Habitation.joins("INNER JOIN leads ON leads.property_id = habitations.id")
      .group(:bairro)
      .order('count_all DESC')
      .limit(5)
      .count

    # Sync Stats
    @last_syncs = Habitation.where.not(last_sync_at: nil).order(last_sync_at: :desc).limit(5)
    @sync_errors_count = Habitation.where(last_sync_status: 'error').count
    @total_synced_count = Habitation.where.not(last_sync_at: nil).count
    
    # Leads by Status
    @leads_by_status = Lead.group(:status).count
  end
end

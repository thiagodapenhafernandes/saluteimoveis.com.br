class Admin::DashboardController < Admin::BaseController
  def index
    # ================= Imóveis =================
    @properties_count    = Habitation.active.count
    @featured_count      = Habitation.featured.count
    @for_sale_count      = Habitation.active.where(status: ['Venda']).count
    @for_rent_count      = Habitation.active.where(status: ['Locação', 'Locacao', 'Aluguel']).count
    @developments_count  = Habitation.empreendimentos.count
    @proprietors_count   = Proprietor.count
    @total_sale_value    = Habitation.active.where("valor_venda_cents > 0").sum(:valor_venda_cents).to_f / 100.0
    @avg_sale_value      = Habitation.active.where("valor_venda_cents > 0").average(:valor_venda_cents).to_f / 100.0
    @recent_properties   = Habitation.newest_first.limit(6)

    # ================= Equipe =================
    @brokers_active     = AdminUser.active.count
    @brokers_inactive   = AdminUser.inactive.count
    @brokers_with_vista = AdminUser.where.not(vista_id: nil).count
    @field_agents_count = AdminUser.where(field_agent_enabled: true).count

    # Top 6 corretores por imóveis atribuídos
    @top_brokers = AdminUser
      .joins(:habitations)
      .where(habitations: { status: [nil, "Venda", "Locação", "Locacao", "Aluguel"] })
      .group("admin_users.id", "admin_users.name")
      .select("admin_users.id, admin_users.name, COUNT(habitations.id) AS ct")
      .order("ct DESC")
      .limit(6)

    # ================= Lojas / Field =================
    @stores_count             = Store.count
    @stores_active_count      = Store.active.count
    @active_checkins_count    = CheckIn.where(status: :active).count
    @today_checkins_count     = CheckIn.today.count
    @suspicious_checkins      = CheckIn.where(suspicious: true).count
    @pending_manual_requests  = ManualCheckinRequest.pending.count
    @field_feature_enabled    = Setting.get("field_checkin_enabled", "false").to_s == "true"

    # Top 5 lojas por check-ins dos últimos 30 dias
    @top_stores = CheckIn
      .where("checked_in_at >= ?", 30.days.ago)
      .joins(:store)
      .group("stores.id", "stores.name")
      .select("stores.id, stores.name, COUNT(check_ins.id) AS ct")
      .order("ct DESC")
      .limit(5)

    # ================= Leads =================
    @total_leads          = Lead.count
    @new_leads            = Lead.where(status: ['Novo', 'novo', nil]).count
    @leads_today          = Lead.where("created_at >= ?", Date.current.beginning_of_day).count
    @leads_last_7_days    = Lead.where("created_at >= ?", 7.days.ago).count
    @leads_last_30_days   = Lead.where("created_at >= ?", 30.days.ago).count
    @holding_leads        = Lead.where(status: :represado).count
    @leads_by_status      = Lead.group(:status).count
    @leads_per_day        = leads_time_series(30)

    # ================= Regras de distribuição =================
    @distribution_rules_total    = DistributionRule.count
    @distribution_rules_active   = DistributionRule.active.count
    @rules_with_checkin          = DistributionRule.where(require_active_checkin: true).count

    # ================= Sync Vista =================
    @sync_errors_count    = Habitation.where(last_sync_status: 'error').count
    @total_synced_count   = Habitation.where.not(last_sync_at: nil).count
    @last_syncs           = Habitation.where.not(last_sync_at: nil).order(last_sync_at: :desc).limit(5)

    # ================= Atividades de hoje =================
    beginning = Date.current.beginning_of_day
    @today_captacoes       = Captacao.where(created_at: beginning..).count
    @today_new_habitations = Habitation.where("COALESCE(data_atualizacao_crm, created_at) >= ?", beginning).count
    @today_audit_events    = CheckinAuditLog.where(created_at: beginning..).count

    # ================= Listas recentes =================
    @recent_habitations = Habitation
      .where.not(data_atualizacao_crm: nil)
      .order(data_atualizacao_crm: :desc)
      .limit(6)

    @recent_captacoes = Captacao
      .includes(:corretor)
      .order(updated_at: :desc)
      .limit(5)

    @drafts_count = Captacao.draft.count

    # ================= Distribuição por categoria =================
    @habitations_by_category = Habitation.active.group(:categoria).count.sort_by { |_, v| -v }.first(6)

    # ================= Atividade recente =================
    @recent_audit_logs = CheckinAuditLog
      .includes(:admin_user, :actor_admin_user)
      .order(created_at: :desc)
      .limit(6)
    @recent_leads = Lead.order(created_at: :desc).limit(6)
  end

  private

  # Retorna array [[date, count], ...] para os últimos N dias (inclusive hoje)
  def leads_time_series(days)
    start_date = days.days.ago.to_date
    rows = Lead
      .where("created_at >= ?", start_date.beginning_of_day)
      .group("DATE(created_at)")
      .count
    (0...days).map do |i|
      d = start_date + i
      [d, rows[d] || 0]
    end
  end
end

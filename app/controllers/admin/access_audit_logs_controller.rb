class Admin::AccessAuditLogsController < Admin::BaseController
  before_action -> { check_permission!(:view, :access_audit) }

  def index
    scope = AccessAuditLog.includes(:admin_user).recent

    scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
    scope = scope.where(result: params[:result]) if params[:result].present?
    scope = scope.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?
    scope = scope.where(ip: params[:ip]) if params[:ip].present?
    scope = scope.where("created_at >= ?", parse_date(params[:start_date])&.beginning_of_day) if params[:start_date].present?
    scope = scope.where("created_at <= ?", parse_date(params[:end_date])&.end_of_day) if params[:end_date].present?

    @logs = scope.paginate(page: params[:page], per_page: 40)
    stats_scope = scope.except(:order, :limit, :offset)
    @total_events = stats_scope.count
    @allowed_events = stats_scope.allowed.count
    @denied_events = stats_scope.denied.count
    @unique_ips = stats_scope.where.not(ip: nil).distinct.count(:ip)
    @available_users = AdminUser.where(id: AccessAuditLog.distinct.pluck(:admin_user_id).compact).order(:name)
  end

  private

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end

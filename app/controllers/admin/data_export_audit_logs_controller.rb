class Admin::DataExportAuditLogsController < Admin::BaseController
  before_action -> { check_permission!(:view, :data_export_audit) }

  def index
    scope = DataExportAuditLog.includes(:admin_user).recent
    scope = scope.where(export_type: params[:export_type]) if params[:export_type].present?
    scope = scope.where(resource_name: params[:resource_name]) if params[:resource_name].present?
    scope = scope.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?
    scope = scope.where(ip: params[:ip]) if params[:ip].present?
    scope = scope.where("created_at >= ?", parse_date(params[:start_date])&.beginning_of_day) if params[:start_date].present?
    scope = scope.where("created_at <= ?", parse_date(params[:end_date])&.end_of_day) if params[:end_date].present?

    @logs = scope.paginate(page: params[:page], per_page: 40)
    stats_scope = scope.except(:order, :limit, :offset)
    @total_exports = stats_scope.count
    @csv_exports = stats_scope.where(export_type: "csv_export").count
    @print_reports = stats_scope.where(export_type: "print_report").count
    @total_records = stats_scope.sum(:record_count)
    @available_users = AdminUser.where(id: DataExportAuditLog.distinct.pluck(:admin_user_id).compact).order(:name)
  end

  private

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end

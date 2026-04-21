# frozen_string_literal: true

module Admin
  module Field
    class AuditLogsController < Admin::BaseController
      before_action -> { check_permission!(:view, :field_audit) }

      def index
        scope = CheckinAuditLog.order(created_at: :desc)
                               .includes(:admin_user, :actor_admin_user, check_in: :store)

        scope = scope.where(action: params[:action_filter]) if params[:action_filter].present?
        scope = scope.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?

        if params[:start_date].present?
          scope = scope.where("created_at >= ?", parse_date(params[:start_date])&.beginning_of_day)
        end
        if params[:end_date].present?
          scope = scope.where("created_at <= ?", parse_date(params[:end_date])&.end_of_day)
        end

        @logs = scope.paginate(page: params[:page], per_page: 40)

        # Stats — computadas sobre a mesma janela de filtros (sem paginação)
        stats_scope = scope.except(:order).except(:limit)
        @total_events        = stats_scope.count
        @events_by_action    = stats_scope.group(:action).count
        @events_today        = CheckinAuditLog.where(created_at: Date.current.beginning_of_day..).count
        @events_last_7_days  = CheckinAuditLog.where(created_at: 7.days.ago..).count
        @flagged_count       = CheckinAuditLog.where(action: "flagged_suspicious").count
        @forced_count        = CheckinAuditLog.where(action: "forced_closed").count

        # Para os filtros
        @available_actions = CheckinAuditLog::ACTIONS
        @available_users   = AdminUser.where(id: CheckinAuditLog.distinct.pluck(:admin_user_id).compact).order(:name)
      end

      def show
        @log = CheckinAuditLog.find(params[:id])
      end

      private

      def parse_date(str)
        Date.parse(str.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end

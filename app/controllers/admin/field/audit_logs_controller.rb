# frozen_string_literal: true

module Admin
  module Field
    class AuditLogsController < Admin::BaseController
      def index
        @logs = CheckinAuditLog.order(created_at: :desc)
                               .includes(:admin_user, :actor_admin_user, :check_in)
                               .limit(200)
        @logs = @logs.where(action: params[:action_filter]) if params[:action_filter].present?
        @logs = @logs.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?
      end

      def show
        @log = CheckinAuditLog.find(params[:id])
      end
    end
  end
end

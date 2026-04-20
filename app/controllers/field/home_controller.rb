# frozen_string_literal: true

module Field
  class HomeController < BaseController
    def show
      @admin_user = current_admin_user
      @default_store = @admin_user.default_store
      @today_shifts = @admin_user
        .store_shifts
        .includes(:store)
        .where(active: true)
        .where(day_of_week: Time.current.wday)
        .order(:start_time)
    end
  end
end

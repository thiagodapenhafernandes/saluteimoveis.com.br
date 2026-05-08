class ApplicationController < ActionController::Base
  before_action :set_admin_robots_header
  before_action :load_layout_settings
  helper_method :current_public_seo_setting

  def current_public_seo_setting
    return @current_public_seo_setting if defined?(@current_public_seo_setting)

    @current_public_seo_setting = Seo::PageTracker.track!(self)
  end

  private

  def set_admin_robots_header
    return unless request.path.start_with?("/admin")

    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive, nosnippet")
  end

  def load_layout_settings
    @layout_setting = LayoutSetting.instance
    @home_setting = HomeSetting.instance
    @footer_setting = FooterSetting.instance
    @footer_links = FooterLink.all
    @footer_stores = Store.active.order(:id)
    @footer_stores = FooterStore.all if @footer_stores.empty?
    @footer_social_links = FooterSocialLink.where(enabled: true)
  end
end

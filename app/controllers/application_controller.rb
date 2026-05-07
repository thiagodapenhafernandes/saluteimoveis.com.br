class ApplicationController < ActionController::Base
  before_action :load_layout_settings

  private

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

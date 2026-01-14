class ApplicationController < ActionController::Base
  before_action :load_layout_settings

  private

  def load_layout_settings
    @layout_setting = LayoutSetting.instance
    @home_setting = HomeSetting.instance
    @footer_setting = FooterSetting.instance
    @footer_links = FooterLink.all
    @footer_stores = FooterStore.all
    @footer_social_links = FooterSocialLink.where(enabled: true)
  end
end

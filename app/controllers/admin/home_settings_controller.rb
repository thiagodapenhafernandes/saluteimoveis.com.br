class Admin::HomeSettingsController < Admin::BaseController
  before_action :set_home_setting
  
  def edit
    # @home_setting já está definido
  end
  
  def update
    if @home_setting.update(home_setting_params)
      redirect_to edit_admin_home_setting_path, notice: 'Configurações atualizadas com sucesso!'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_home_setting
    @home_setting = HomeSetting.instance
  end
  
  def home_setting_params
    params.require(:home_setting).permit(
      :hero_title,
      :hero_subtitle,
      :hero_cta_text,
      :hero_cta_link,
      :overlay_opacity,
      :overlay_color,
      :cta_title,
      :cta_subtitle,
      :services_active,
      :why_choose_active,
      :cta_contact_active,
      :hero_background_desktop,
      :hero_background_mobile,
      :hero_button_color,
      :hero_button_text_color
    )
  end
end

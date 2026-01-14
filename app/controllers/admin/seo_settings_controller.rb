class Admin::SeoSettingsController < Admin::BaseController
  before_action :set_seo_setting, only: [:edit, :update, :destroy]

  def index
    @seo_settings = SeoSetting.all.order(:page_name)
  end

  def new
    @seo_setting = SeoSetting.new
  end

  def create
    @seo_setting = SeoSetting.new(seo_setting_params)
    if @seo_setting.save
      redirect_to admin_seo_settings_path, notice: 'SEO criado com sucesso!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @seo_setting.update(seo_setting_params)
      redirect_to admin_seo_settings_path, notice: 'SEO atualizado!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @seo_setting.destroy
    redirect_to admin_seo_settings_path, notice: 'SEO removido!'
  end

  private

  def set_seo_setting
    @seo_setting = SeoSetting.find(params[:id])
  end

  def seo_setting_params
    params.require(:seo_setting).permit(
      :page_name,
      :meta_title,
      :meta_description,
      :meta_keywords,
      :og_image,
      :canonical_url,
      :og_image_file
    )
  end
end

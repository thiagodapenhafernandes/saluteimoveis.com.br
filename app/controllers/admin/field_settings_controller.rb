class Admin::FieldSettingsController < Admin::BaseController
  def edit
    @enabled = FieldFeatureGate.field_checkin_enabled?
  end

  def update
    value = ActiveModel::Type::Boolean.new.cast(params[:enabled]) ? "true" : "false"
    Setting.set(FieldFeatureGate::SETTING_KEY, value)
    redirect_to edit_admin_field_settings_path, notice: "Feature check-in #{value == 'true' ? 'ativada' : 'desativada'}."
  end
end

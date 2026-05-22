class Admin::AccessSecurityController < Admin::BaseController
  before_action -> { check_permission!(:manage, :access_security) }

  def show
    load_dashboard
  end

  def update
    Setting.set(AccessControl::Settings::ENFORCE_BROKER_IP_KEY, truthy?(params[:enforce_broker_ip_allowlist]).to_s, "Exigir IP permitido para corretores")
    Setting.set(AccessControl::Settings::ENFORCE_BROKER_DEVICE_KEY, truthy?(params[:enforce_broker_trusted_devices]).to_s, "Exigir aparelho confiável para corretores")

    redirect_to admin_access_security_path, notice: "Configurações de segurança atualizadas."
  end

  private

  def load_dashboard
    @rules = AccessControlRule.includes(:profile, :admin_user, :created_by).recent
    @trusted_devices = TrustedDevice.includes(:admin_user, :created_by).recent.limit(80)
    @profiles = Profile.order(:name)
    @admin_users = AdminUser.order(:name)
    @new_rule = AccessControlRule.new(scope_type: "global", rule_type: "allow_ip", enabled: true)
    @broker_ip_allowlist_enabled = AccessControl::Settings.broker_ip_allowlist_enabled?
    @broker_trusted_devices_enabled = AccessControl::Settings.broker_trusted_devices_enabled?
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end

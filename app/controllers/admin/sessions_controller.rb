class Admin::SessionsController < Devise::SessionsController
  layout 'admin_login'
  
  def after_sign_in_path_for(resource)
    # Corretor (não-admin) vai direto pro PWA /field — ambiente mobile-first
    # com hub de atalhos (captações, leads, imóveis, check-in).
    # Admin continua no painel tradicional /admin.
    return field_root_path if resource.respond_to?(:admin?) && !resource.admin?
    admin_root_path
  end
  
  def after_sign_out_path_for(resource_or_scope)
    new_admin_user_session_path
  end
end

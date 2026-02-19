class Admin::BaseController < ApplicationController
  before_action :authenticate_admin_user!
  layout 'admin'
  
  private
  
  def authenticate_admin_user!
    unless current_admin_user
      redirect_to new_admin_user_session_path, alert: 'Acesso negado. Por favor, faça login.'
    end
  end
  
  def require_admin!
    unless current_admin_user&.admin?
      redirect_to admin_root_path, alert: 'Acesso negado. Apenas administradores.'
    end
  end

  def check_permission!(action, resource)
    unless current_admin_user&.can?(action, resource)
      redirect_to admin_root_path, alert: 'Você não tem permissão para acessar esta área.'
    end
  end

  helper_method :can?

  def can?(action, resource)
    current_admin_user&.can?(action, resource)
  end
end

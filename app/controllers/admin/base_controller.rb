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
end

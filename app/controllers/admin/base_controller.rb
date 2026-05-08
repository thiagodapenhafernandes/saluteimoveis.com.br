class Admin::BaseController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :prevent_search_indexing
  layout 'admin'
  
  private
  
  def authenticate_admin_user!
    unless current_admin_user
      redirect_to new_admin_user_session_path, alert: 'Acesso negado. Por favor, faça login.'
    end
  end

  def prevent_search_indexing
    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive, nosnippet")
  end
  
  def require_admin!
    unless current_admin_user&.admin?
      redirect_to admin_root_path, alert: 'Acesso negado. Apenas administradores.'
    end
  end

  def check_permission!(action, resource)
    unless current_admin_user&.can?(action, resource)
      respond_to do |format|
        format.html { redirect_to admin_root_path, alert: "Você não tem permissão para acessar esta área." }
        format.json { render json: { error: "forbidden" }, status: :forbidden }
      end
    end
  end

  # Retorna scope do usuário para o recurso ("own" ou "all").
  def scope_for_resource(resource)
    current_admin_user&.scope_for(resource) || "own"
  end

  def owns_all_resource?(resource)
    current_admin_user&.owns_all?(resource)
  end

  helper_method :can?, :scope_for_resource, :owns_all_resource?

  def can?(action, resource)
    current_admin_user&.can?(action, resource)
  end
end

module Admin
  class AdminUsersController < BaseController
    before_action :set_admin_user, only: %i[show edit update destroy]

    def sync_from_vista
      status = Vista::SyncStatusService.new.snapshot
      if status[:status] == "processing"
        redirect_to admin_admin_users_path, alert: "Uma sincronização já está em andamento."
        return
      end

      Vista::ImportAgentsJob.perform_later
      redirect_to admin_admin_users_path,
                  notice: "Sincronização de corretores do Vista iniciada em background."
    end

    def vista_sync_status
      @status = Vista::SyncStatusService.new.snapshot
      render partial: "admin/admin_users/vista_sync_panel", locals: { status: @status }
    end

    def index
      @admin_users = AdminUser.includes(:profile, :manager)

      if params[:query].present?
        q = "%#{params[:query]}%"
        @admin_users = @admin_users.where("name ILIKE ? OR email ILIKE ? OR vista_id ILIKE ? OR creci ILIKE ?", q, q, q, q)
      end

      if params[:profile_id].present?
        @admin_users = @admin_users.where(profile_id: params[:profile_id])
      end

      @admin_users = @admin_users.order(name: :asc).paginate(page: params[:page], per_page: 20)
    end

    def show
    end

    def new
      @admin_user = AdminUser.new
    end

    def edit
    end

    def create
      @admin_user = AdminUser.new(admin_user_params)
      if @admin_user.save
        redirect_to admin_admin_users_path, notice: 'Usuário criado com sucesso.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if params[:admin_user][:password].blank?
        params[:admin_user].delete(:password)
        params[:admin_user].delete(:password_confirmation)
      end

      if @admin_user.update(admin_user_params)
        redirect_to admin_admin_users_path, notice: 'Usuário atualizado com sucesso.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @admin_user.destroy
      redirect_to admin_admin_users_path, notice: 'Usuário excluído com sucesso.'
    end

    private

    def set_admin_user
      @admin_user = AdminUser.find(params[:id])
    end

    def admin_user_params
      params.require(:admin_user).permit(:email, :password, :password_confirmation, :name, :role, :profile_id, :manager_id, :creci, :phone, :biography, :birth_date, :city, :avatar, :acting_type)
    end
  end
end

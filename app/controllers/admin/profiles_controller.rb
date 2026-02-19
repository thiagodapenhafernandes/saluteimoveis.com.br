module Admin
  class ProfilesController < BaseController
    before_action :set_profile, only: %i[show edit update destroy]

    def index
      @profiles = Profile.all.order(name: :asc)
    end

    def show
    end

    def new
      @profile = Profile.new
    end

    def edit
    end

    def create
      @profile = Profile.new(profile_params)
      if @profile.save
        redirect_to admin_profiles_path, notice: 'Perfil criado com sucesso.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @profile.update(profile_params)
        redirect_to admin_profiles_path, notice: 'Perfil atualizado com sucesso.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @profile.destroy
      redirect_to admin_profiles_path, notice: 'Perfil excluído com sucesso.'
    end

    private

    def set_profile
      @profile = Profile.find(params[:id])
    end

    def profile_params
      params.require(:profile).permit(:name, :active, permissions: {})
    end
  end
end

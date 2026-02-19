module Admin
  class ConstructorsController < BaseController
    before_action :set_constructor, only: %i[show edit update destroy]
  require 'open-uri'

  def proxy_logo
    url = params[:url]
    # Security: Whitelist allowed domains for proxying
    allowed_domains = %w[www.google.com]
    
    unless url.present? && allowed_domains.any? { |d| url.start_with?("https://#{d}/") }
      return head :forbidden
    end

    begin
      # Set open timeout to avoid hanging requests
      data = URI.open(url, open_timeout: 3, read_timeout: 3).read
      
      # Determine content type (fallback to png)
      send_data data, type: 'image/png', disposition: 'inline'
    rescue OpenURI::HTTPError => e
      head :not_found
    rescue => e
      Rails.logger.error "Proxy Error: #{e.message}"
      head :bad_gateway
    end
  end

  def index
      @constructors = Constructor.all.order(name: :asc)

      if params[:q].present?
        @constructors = @constructors.where("name ILIKE ?", "%#{params[:q]}%")
      end

      @constructors = @constructors.paginate(page: params[:page], per_page: 15)
    end

    def show
    end

    def new
      @constructor = Constructor.new
    end

    def edit
    end

    def create
      @constructor = Constructor.new(constructor_params)
      
      respond_to do |format|
        if @constructor.save
          format.html { redirect_to admin_constructors_path, notice: 'Construtora criada com sucesso.' }
          format.turbo_stream
          format.json { render json: @constructor, status: :created }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream { render turbo_stream: turbo_stream.replace('new_constructor_form', partial: 'form', locals: { constructor: @constructor }) }
          format.json { render json: { errors: @constructor.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def update
      if @constructor.update(constructor_params)
        redirect_to admin_constructors_path, notice: 'Construtora atualizada com sucesso.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @constructor.destroy
      redirect_to admin_constructors_path, notice: 'Construtora excluída com sucesso.'
    end

    private

    def set_constructor
      @constructor = Constructor.find(params[:id])
    end

    def constructor_params
      params.require(:constructor).permit(:name, :website_url, :logo)
    end
  end
end

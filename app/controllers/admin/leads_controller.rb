class Admin::LeadsController < Admin::BaseController
  before_action :set_lead, only: [:show, :update, :destroy]
  before_action :load_origin_options, only: [:index, :show, :update]

  def index
    @q = params[:q]
    @status = params[:status]
    @origin = params[:origin]

    @leads = Lead.order(created_at: :desc)
    
    if @q.present?
      @leads = @leads.where("name ILIKE :q OR email ILIKE :q OR phone ILIKE :q OR origin ILIKE :q", q: "%#{@q}%")
    end
    
    @leads = @leads.where(status: @status) if @status.present?
    @leads = @leads.by_origin(@origin)

    @leads = @leads.paginate(page: params[:page], per_page: 20)
    @page_title = "Gerenciar Leads"
  end

  def show
    @page_title = "Lead: #{@lead.name}"
    @property = Habitation.find_by(id: @lead.property_id)
  end

  def update
    if @lead.update(lead_params)
      redirect_to admin_lead_path(@lead), notice: "Lead atualizado com sucesso."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @lead.destroy
    redirect_to admin_leads_path, notice: "Lead excluído com sucesso."
  end

  private

  def set_lead
    @lead = Lead.find(params[:id])
  end

  def lead_params
    params.require(:lead).permit(:status, :notes, :origin)
  end

  def load_origin_options
    @origin_options = Lead.origin_options
  end
end

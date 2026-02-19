class Admin::MetaIntegrationsController < Admin::BaseController
  before_action :set_integration
  before_action :set_page, only: [:list_forms]

  def index
    # Show status and link to Facebook Login if not integrated
    @pages = @integration&.meta_facebook_pages || []
  end

  def list_forms
    @forms = @page.meta_lead_forms.order(facebook_created_at: :desc)
    render layout: false
  end

  def sync_pages
    return redirect_to admin_meta_integrations_path, alert: "Conecte-se ao Facebook primeiro." unless @integration

    @integration.update!(sync_status: 'processing', sync_progress: 0)
    MetaSyncJob.perform_later(@integration.id)
    redirect_to admin_meta_integrations_path, notice: "A sincronização foi iniciada em segundo plano."
  rescue => e
    redirect_to admin_meta_integrations_path, alert: "Erro ao iniciar sincronização: #{e.message}"
  end

  def sync_forms
    return redirect_to admin_meta_integrations_path, alert: "Conecte-se ao Facebook primeiro." unless @integration

    @integration.update!(sync_status: 'processing', sync_progress: 0)
    MetaSyncJob.perform_later(@integration.id)
    redirect_to admin_meta_integrations_path, notice: "A sincronização dos formulários foi iniciada."
  rescue => e
    redirect_to admin_meta_integrations_path, alert: "Erro ao iniciar sincronização: #{e.message}"
  end

  def disconnect
    @integration&.destroy
    redirect_to admin_meta_integrations_path, notice: "Conta do Facebook desconectada."
  end

  private

  def set_integration
    @integration = UserMetaIntegration.find_by(admin_user: current_admin_user)
  end

  def set_page
    @page = @integration.meta_facebook_pages.find(params[:page_id])
  end
end

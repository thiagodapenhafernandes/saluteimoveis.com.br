class Admin::DistributionRulesController < Admin::BaseController
  before_action :set_rule, only: [:show, :edit, :update, :destroy, :toggle_active]
  before_action :load_meta_options, only: [:new, :create, :edit, :update]
  before_action :load_team_structure, only: [:new, :create, :edit, :update]

  def index
    @distribution_rules = DistributionRule.all.order(created_at: :desc)
    @holding_leads_count = Lead.represado.count
  end

  def show
    @agents_queue = @rule.distribution_rule_agents.includes(:admin_user).order(position: :asc)
  end

  def new
    @distribution_rule = DistributionRule.new
    @distribution_rule.ensure_full_schedule
  end

  def create
    @distribution_rule = DistributionRule.new(rule_params)
    populate_meta_forms_if_auto
    if @distribution_rule.save
      redirect_to admin_distribution_rule_path(@distribution_rule), notice: "Regra criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @distribution_rule.assign_attributes(rule_params)
    populate_meta_forms_if_auto
    if @distribution_rule.save
      redirect_to admin_distribution_rule_path(@distribution_rule), notice: "Regra atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to admin_distribution_rules_path, notice: "Regra excluída."
  end

  def toggle_active
    @rule.update(active: !@rule.active)
    redirect_to admin_distribution_rules_path, notice: "Status da regra atualizado."
  end

  private

  def set_rule
    @rule = DistributionRule.find(params[:id])
    @distribution_rule = @rule # For form compatibility
  end

  def load_meta_options
    @meta_structure = {}
    MetaFacebookPage.where(active: true).includes(:meta_lead_forms).each do |page|
      forms_list = page.meta_lead_forms.map { |f| { id: f.form_id, name: f.name } }
      @meta_structure[page.page_id] = { name: page.name, forms: forms_list }
    end

    @all_form_options = []
    MetaFacebookPage.where(active: true).includes(:meta_lead_forms).each do |page|
      page.meta_lead_forms.each do |form|
        @all_form_options << [ "#{form.name} · #{page.name}", form.form_id ]
      end
    end
    @all_page_options = MetaFacebookPage.where(active: true).map { |p| [ p.name, p.page_id ] }
  end

  def load_team_structure
    @team_structure = {}
    
    # Get all admins who have subordinates
    managers = AdminUser.joins(:subordinates).distinct.includes(:subordinates)
    
    managers.each do |manager|
      @team_structure[manager.id] = {
        name: manager.name,
        agents: manager.subordinates.map { |s| { id: s.id, name: s.name } }
      }
    end

    @all_users_options = AdminUser.all.order(:name).map { |u| [ u.name, u.id ] }
    @manager_options = managers.map { |m| [ m.name, m.id ] }
  end

  def populate_meta_forms_if_auto
    return unless @distribution_rule.auto_add_forms?
    page_ids = @distribution_rule.meta_page_ids.reject(&:blank?)
    if page_ids.any?
      pages = MetaFacebookPage.where(page_id: page_ids)
      all_forms = MetaLeadForm.where(meta_facebook_page_id: pages.select(:id)).pluck(:form_id)
      @distribution_rule.meta_forms = all_forms
    end
  end

  def rule_params
    # For JSONB fields like represamento_schedule, we permit the whole hash
    params.require(:distribution_rule).permit(
      :name, :business_type, :active,
      :source_meta, :source_webhook, :source_portal, :source_site,
      :distribution_mode,
      :pocket_active, :pocket_time,
      :represamento_active, :auto_add_forms,
      :min_price, :max_price,
      :notify_whatsapp, :notify_email, :notify_webhook,
      :webhook_url,
      admin_user_ids: [],
      meta_forms: [],
      meta_page_ids: [],
      webhook_tags: [],
      neighborhoods: [],
      represamento_schedule: {},
      custom_filters: {}
    )
  end
end

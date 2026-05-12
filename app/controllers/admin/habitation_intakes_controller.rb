module Admin
  class HabitationIntakesController < Admin::BaseController
    before_action -> { check_permission!(:view, :captacoes) }
    before_action -> { check_permission!(:manage, :captacoes) }, only: %i[new create edit update destroy submit_for_review release_to_site publish]
    before_action :set_habitation, only: %i[show edit update destroy submit_for_review approve return_to_broker release_to_site]
    before_action :authorize_access!, only: %i[show edit update destroy submit_for_review release_to_site]
    before_action :authorize_review!, only: %i[approve return_to_broker]
    before_action :load_form_options, only: %i[edit update]
    layout :resolve_layout

    def index
      @status = params[:status].presence
      @q = params[:q].to_s.strip
      @habitations = scoped_intakes.includes(:admin_user, :admin_reviewed_by, :address)
      @habitations = @habitations.where(categoria: "Terreno") if params[:property_kind] == "terreno"
      @habitations = @habitations.where(categoria: "Sala Comercial") if params[:property_kind] == "sala_comercial"
      @habitations = @habitations.where.not(categoria: ["Terreno", "Sala Comercial"]) if params[:property_kind] == "residencial"
      case @status
      when "draft"
        @habitations = @habitations.where(intake_status: [nil, "draft", "returned_to_broker"])
      when "completed"
        @habitations = @habitations.where(intake_status: %w[submitted_for_admin_review admin_approved])
      when "published"
        @habitations = @habitations.where(intake_status: "published")
      else
        @habitations = @habitations.where(intake_status: @status) if @status.present?
      end
      if @q.present?
        @habitations = @habitations.where(
          "codigo ILIKE :q OR titulo_anuncio ILIKE :q OR nome_empreendimento ILIKE :q OR proprietario ILIKE :q",
          q: "%#{@q}%"
        )
      end
      @habitations = @habitations.order(updated_at: :desc).paginate(page: params[:page], per_page: 20)
      @captacoes = @habitations
      render "admin/captacoes/index"
    end

    def new
      start_new_intake
    end

    def create
      start_new_intake
    end

    def show
      @captacao = @habitation
      render "admin/captacoes/show"
    end

    def edit
      @captacao = @habitation
      @step = params[:step].presence_in(Captacao::STEPS) || @habitation.intake_step.presence || "intro"
      @step = @captacao.next_step if @step == "visitas" && @captacao.skip_visitas?
      render "admin/captacoes/edit"
    end

    def update
      @captacao = @habitation
      current_step = params[:current_step].presence_in(Captacao::STEPS) || @habitation.intake_step.presence || "intro"
      direction = params[:direction].to_s

      if direction == "back"
        target = @habitation.previous_step || current_step
        @habitation.assign_attributes(captacao_style_params) if intake_param_key.present?
        @habitation.update_column(:intake_step, target)
        redirect_to edit_admin_captacao_path(@habitation, step: target)
        return
      end

      if published_restricted_update?
        @habitation.assign_attributes(published_restricted_params)
      else
        @habitation.assign_attributes(captacao_style_params)
      end

      if duplicate_address_blocks_intake?(current_step)
        assign_duplicate_address_errors
        @step = current_step
        render "admin/captacoes/edit", status: :unprocessable_entity
        return
      end

      if @habitation.save
        unless step_requirements_met?(current_step)
          assign_step_errors(current_step)
          @step = current_step
          @habitation.update_column(:intake_step, current_step) if @habitation.persisted?
          render "admin/captacoes/edit", status: :unprocessable_entity
          return
        end

        if current_step == "review"
          unless @habitation.intake_ready_for_admin_review?
            @habitation.intake_missing_requirements.each { |message| @habitation.errors.add(:base, message) }
            @step = current_step
            render "admin/captacoes/edit", status: :unprocessable_entity
            return
          end

          @habitation.update_columns(intake_status: "submitted_for_admin_review", submitted_for_review_at: Time.current, intake_step: current_step)
          redirect_to admin_captacao_path(@habitation), notice: "Captação enviada para aprovação administrativa."
        else
          next_step = @habitation.next_step
          next_step = @habitation.next_step if next_step == "visitas" && @habitation.skip_visitas?
          @habitation.update_column(:intake_step, next_step)
          redirect_to edit_admin_captacao_path(@habitation, step: next_step)
        end
      else
        @step = current_step
        render "admin/captacoes/edit", status: :unprocessable_entity
      end
    end

    def destroy
      if @habitation.intake_published?
        redirect_to admin_captacoes_path, alert: "Captações já liberadas para site não podem ser removidas por aqui."
      else
        @habitation.destroy
        redirect_to admin_captacoes_path, notice: "Captação removida."
      end
    end

    def submit_for_review
      @habitation.assign_attributes(captacao_style_params) if intake_param_key.present?

      if duplicate_address_blocks_intake?("review")
        load_form_options
        assign_duplicate_address_errors
        flash.now[:alert] = "Complete os campos obrigatórios antes de enviar."
        @captacao = @habitation
        @step = "review"
        render "admin/captacoes/edit", status: :unprocessable_entity
        return
      end

      if @habitation.intake_ready_for_admin_review? && @habitation.save
        @habitation.update!(intake_status: "submitted_for_admin_review", submitted_for_review_at: Time.current)
        redirect_to admin_captacao_path(@habitation), notice: "Captação enviada para aprovação administrativa."
      else
        load_form_options
        @missing_requirements = @habitation.intake_missing_requirements
        flash.now[:alert] = "Complete os campos obrigatórios antes de enviar."
        @captacao = @habitation
        @step = "review"
        render "admin/captacoes/edit", status: :unprocessable_entity
      end
    end

    def approve
      @habitation.update!(
        intake_status: "admin_approved",
        admin_reviewed_by: current_admin_user,
        admin_reviewed_at: Time.current,
        admin_review_notes: params[:admin_review_notes]
      )
      redirect_to admin_captacao_path(@habitation), notice: "Captação liberada pelo administrativo."
    end

    def return_to_broker
      @habitation.update!(
        intake_status: "returned_to_broker",
        admin_reviewed_by: current_admin_user,
        admin_reviewed_at: Time.current,
        admin_review_notes: params[:admin_review_notes]
      )
      redirect_to admin_captacao_path(@habitation), notice: "Captação devolvida ao corretor."
    end

    def release_to_site
      unless @habitation.broker_can_release_to_site?
        redirect_to admin_captacao_path(@habitation), alert: "Esta captação ainda não está pronta para liberar no site."
        return
      end

      @habitation.update!(
        intake_status: "published",
        broker_released_at: Time.current,
        exibir_no_site_flag: true,
        foto_classificacao: @habitation.foto_classificacao.presence || "Boas"
      )
      redirect_to admin_captacao_path(@habitation), notice: "Imóvel liberado para o site."
    end

    def publish
      if @habitation.intake_admin_approved?
        release_to_site
      elsif can?(:review, :captacoes)
        approve
      else
        redirect_to admin_captacao_path(@habitation), alert: "Captação ainda precisa de aprovação administrativa."
      end
    end

    private

    def start_new_intake
      habitation = Habitation.create!(
        admin_user: current_admin_user,
        intake_origin: Habitation::INTAKE_ORIGIN_BROKER,
        intake_status: "draft",
        exibir_no_site_flag: false,
        categoria: "Apartamento",
        status: default_status,
        tipo: "Unitário",
        foto_classificacao: "Não tem fotos"
      )
      redirect_to edit_admin_captacao_path(habitation), notice: "Captação iniciada."
    end

    def set_habitation
      @habitation = Habitation.broker_intakes.friendly.find(params[:id])
    end

    def scoped_intakes
      scope = Habitation.broker_intakes
      return scope if owns_all_resource?(:captacoes) || can?(:review, :captacoes)

      scope.where(admin_user_id: current_admin_user.id)
    end

    def authorize_access!
      return if owns_all_resource?(:captacoes) || can?(:review, :captacoes)
      return if @habitation.admin_user_id == current_admin_user.id

      redirect_to admin_captacoes_path, alert: "Você não tem acesso a esta captação."
    end

    def authorize_review!
      return if can?(:review, :captacoes)

      redirect_to admin_captacoes_path, alert: "Você não tem permissão para aprovar captações."
    end

    def default_status
      current_admin_user&.rentals? ? "Aluguel" : "Venda"
    end

    def load_form_options
      @brokers = AdminUser.order(:name)
      @proprietors = Proprietor.order(:name).limit(300)
      @internal_features = (
        AttributeOption.where(context: "habitation", category: "feature").order(:name).pluck(:name) +
        Admin::HabitationsController::CUSTOM_FEATURE_OPTIONS
      ).uniq.sort
      @external_features = AttributeOption.where(context: "habitation", category: "infrastructure").order(:name).pluck(:name)
      @badges = AttributeOption.where(context: "habitation", category: "unique_feature").order(:name).pluck(:name)
      @sale_reasons = sale_reason_options
      @photography_blocked_dates = PhotographyScheduleBlock.pluck(:date).map(&:iso8601)
      @photography_booked_slots = Habitation
        .broker_intakes
        .where(photo_flow_choice: "schedule")
        .where.not(id: @habitation&.id)
        .where.not(photo_session_requested_at: nil)
        .pluck(:photo_session_requested_at)
        .map { |date| date.strftime("%Y-%m-%dT%H:%M") }
    end

    def resolve_layout
      action_name.in?(%w[new create edit update]) ? "captacao_wizard" : "admin"
    end

    def step_requirements_met?(step)
      step_missing_requirements(step).empty?
    end

    def assign_step_errors(step)
      @step_errors = step_missing_requirements(step)
      @invalid_fields = invalid_fields_for_step(step)
      @step_errors.each { |message| @habitation.errors.add(:base, message) }
    end

    def step_missing_requirements(step)
      case step
      when "proprietario"
        missing = []
        missing << "Informe o nome do proprietário." if @habitation.proprietario.blank?
        missing << "Informe o telefone/WhatsApp do proprietário." if @habitation.proprietario_celular.blank?
        missing
      when "endereco"
        missing = []
        missing << "Informe o CEP." if @habitation.cep.blank?
        missing << "Informe a rua/avenida." if @habitation.logradouro.blank?
        missing << "Informe o número." if @habitation.numero.blank?
        missing << "Informe o bairro." if @habitation.bairro.blank?
        missing << "Informe a cidade." if @habitation.cidade.blank?
        missing << "Informe a UF." if @habitation.uf.blank?
        missing << "Informe o nome do condomínio/empreendimento." if !@habitation.property_kind_terreno? && @habitation.nome_empreendimento.blank?
        missing
      when "caracteristicas"
        missing = []
        missing << "Informe a área total do imóvel." if @habitation.area_total_m2.to_f <= 0
        if @habitation.property_kind_residencial? && @habitation.dormitorios_qtd.to_i <= 0
          missing << "Informe a quantidade de dormitórios."
        end
        if @habitation.property_kind_residencial? && @habitation.banheiros_qtd.to_i <= 0
          missing << "Informe a quantidade de banheiros."
        end
        missing << "Marque ao menos uma característica do imóvel." if @habitation.caracteristicas.blank?
        missing << "Marque ao menos uma característica do edifício." if !@habitation.property_kind_terreno? && @habitation.infra_estrutura.blank?
        missing
      when "negociacao"
        missing = []
        if @habitation.requires_sale_price? && !@habitation.valid_intake_sale_price?
          missing << @habitation.intake_sale_price_requirement_message
        end
        if @habitation.requires_rent_price? && !@habitation.valid_intake_rent_price?
          missing << @habitation.intake_rent_price_requirement_message
        end
        missing << "Informe ao menos condomínio ou IPTU." if @habitation.valor_condominio_cents.blank? && @habitation.valor_iptu_cents.blank?
        missing << "Informe se aceita permuta." if @habitation.sale_intake? && @habitation.aceita_permuta_answer.blank?
        if @habitation.rental_intake? && @habitation.salute_rental_management_answer.blank?
          missing << "Informe se a administração da locação será feita pela Salute."
        end
        missing << "Informe em quantas vezes aceita parcelamento." if @habitation.aceita_parcelamento_flag? && @habitation.numero_prestacoes.blank?
        missing
      when "fotos"
        missing = []
        missing << "Escolha se vai enviar fotos ou agendar fotógrafo." if @habitation.photo_flow_choice.blank?
        missing << "Envie ao menos uma foto do imóvel." if @habitation.photo_flow_choice == "upload" && !@habitation.has_any_photo?
        missing << "Informe a data/hora agendada com fotógrafo." if @habitation.photo_flow_choice == "schedule" && @habitation.photo_session_requested_at.blank?
        missing << "Anexe a autorização do proprietário." unless @habitation.autorizacoes_venda.attached?
        missing
      else
        []
      end
    end

    def invalid_fields_for_step(step)
      fields = {}
      case step
      when "proprietario"
        fields[:proprietario_nome] = true if @habitation.proprietario.blank?
        fields[:proprietario_telefone] = true if @habitation.proprietario_celular.blank?
      when "endereco"
        fields[:zip_code] = true if @habitation.cep.blank?
        fields[:street] = true if @habitation.logradouro.blank?
        fields[:street_number] = true if @habitation.numero.blank?
        fields[:neighborhood] = true if @habitation.bairro.blank?
        fields[:city] = true if @habitation.cidade.blank?
        fields[:state] = true if @habitation.uf.blank?
        fields[:edificio_nome] = true if !@habitation.property_kind_terreno? && @habitation.nome_empreendimento.blank?
      when "caracteristicas"
        fields[:area_total] = true if @habitation.area_total_m2.to_f <= 0
        fields[:dormitorios] = true if @habitation.property_kind_residencial? && @habitation.dormitorios_qtd.to_i <= 0
        fields[:banheiros] = true if @habitation.property_kind_residencial? && @habitation.banheiros_qtd.to_i <= 0
        fields[:caracteristicas_imovel] = true if @habitation.caracteristicas.blank?
        fields[:caracteristicas_predio] = true if !@habitation.property_kind_terreno? && @habitation.infra_estrutura.blank?
      when "negociacao"
        fields[:valor_venda] = true if @habitation.requires_sale_price? && !@habitation.valid_intake_sale_price?
        fields[:valor_locacao] = true if @habitation.requires_rent_price? && !@habitation.valid_intake_rent_price?
        if @habitation.valor_condominio_cents.blank? && @habitation.valor_iptu_cents.blank?
          fields[:valor_condominio] = true
          fields[:valor_iptu] = true
        end
        fields[:aceita_permuta_answer] = true if @habitation.sale_intake? && @habitation.aceita_permuta_answer.blank?
        fields[:salute_rental_management_answer] = true if @habitation.rental_intake? && @habitation.salute_rental_management_answer.blank?
        fields[:numero_prestacoes] = true if @habitation.aceita_parcelamento_flag? && @habitation.numero_prestacoes.blank?
      when "fotos"
        fields[:photo_flow_choice] = true if @habitation.photo_flow_choice.blank?
        fields[:photos] = true if @habitation.photo_flow_choice == "upload" && !@habitation.has_any_photo?
        fields[:photo_session_requested_at] = true if @habitation.photo_flow_choice == "schedule" && @habitation.photo_session_requested_at.blank?
        fields[:autorizacoes_venda] = true unless @habitation.autorizacoes_venda.attached?
      end
      fields
    end

    def duplicate_address_blocks_intake?(step)
      return false unless step.in?(%w[endereco review])

      duplicate_address_result.complete && duplicate_address_result.duplicate?
    end

    def duplicate_address_result
      @duplicate_address_result ||= HabitationDuplicateChecker.new(
        street: @habitation.logradouro,
        number: @habitation.numero,
        building: @habitation.nome_empreendimento,
        unit: @habitation.bloco,
        ignored_id: @habitation.id
      ).call
    end

    def assign_duplicate_address_errors
      duplicated = duplicate_address_result.matches.first
      code = duplicated&.codigo.present? ? " ##{duplicated.codigo}" : ""
      message = "Já existe imóvel cadastrado com esta rua, número, prédio e unidade#{code}."
      @invalid_fields ||= {}
      @invalid_fields[:street] = true
      @invalid_fields[:street_number] = true
      @invalid_fields[:edificio_nome] = true
      @invalid_fields[:unidade_numero] = true
      @step_errors ||= []
      @step_errors << message
      @missing_requirements ||= []
      @missing_requirements << message
      @habitation.errors.add(:base, message)
    end

    def published_restricted_update?
      @habitation.intake_published? && !can?(:manage, :imoveis)
    end

    def published_restricted_params
      params.require(:habitation).permit(
        :status,
        :valor_venda_formatted,
        :valor_locacao_formatted,
        :valor_promocional_formatted,
        :valor_condominio_formatted,
        :valor_iptu_formatted,
        :ordered_photo_ids
      )
    end

    def intake_param_key
      return :habitation if params[:habitation].present?
      return :captacao if params[:captacao].present?
    end

    def captacao_style_params
      permitted_keys = [
        :categoria, :status, :situacao, :tipo, :nome_empreendimento, :titulo_anuncio,
        :property_kind, :modalidade, :step,
        :dormitorios_qtd, :suites_qtd, :banheiros_qtd, :vagas_qtd, :elevadores_qtd,
        :area_total, :area_privativa, :dormitorios, :suites, :demi_suites, :salas, :banheiros, :vagas_garagem,
        :ocupacao, :estado_imovel, :situacao_imovel, :sacada, :terraco, :dependencia_empregada, :precisa_reforma,
        :andares_total, :aptos_por_andar, :distancia_praia,
        :area_privativa_m2, :area_total_m2, :area_terreno_m2, :area_util_m2,
        :valor_venda, :valor_locacao, :valor_condominio, :valor_iptu, :saldo_devedor,
        :valor_venda_formatted, :valor_locacao_formatted, :valor_condominio_formatted,
        :valor_iptu_formatted, :saldo_devedor_formatted,
        :motivo_venda, :cidade_permuta, :aceita_parcelamento,
        :descricao_web, :descricao_interna, :observacoes, :condicoes_negociacao, :observacoes_visitas,
        :proprietario_nome, :proprietario_telefone, :proprietario_cpf_cnpj, :proprietario_cidade,
        :proprietario, :proprietario_celular, :proprietario_email,
        :proprietario_telefone_comercial, :proprietario_telefone_residencial,
        :proprietario_codigo, :proprietor_id, :admin_user_id,
        :foto_classificacao, :photo_flow_choice, :photo_session_requested_at, :photo_session_url,
        :salute_rental_management_answer, :aceita_permuta_answer,
        :aceita_parcelamento_flag, :numero_prestacoes, :aceita_financiamento_flag,
        :aceita_permuta_veiculo_flag, :aceita_permuta_imovel_flag, :aceita_permuta_outros_flag,
        :mobiliado_flag, :exclusivo_flag, :ocupacao_status, :estado_conservacao,
        :andar, :ano_construcao, :demi_suites_qtd, :numero_box, :tipo_vaga,
        :dimensoes_terreno, :topografia, :key_location, :key_location_notes,
        :corretor_nome, :corretor_telefone, :corretor_email, :ordered_photo_ids,
        :zip_code, :street, :street_number, :neighborhood, :city, :state, :edificio_nome, :unidade_numero,
        :chaves_com, :senha_imovel, :senha_portaria,
        { caracteristicas: [], infra_estrutura: [], caracteristica_unica: [],
          caracteristicas_imovel: [], caracteristicas_predio: [], aceita_permuta: [], outras_taxas: [], dias_visitas: [],
          photos: [], fotos: [], autorizacoes_venda: [], fichas_cadastro: [], autorizacao_pdf: [],
          extras: {},
          address_attributes: [:id, :tipo_endereco, :logradouro, :numero, :complemento, :bairro, :bairro_comercial, :cidade, :uf, :cep, :pais, :latitude, :longitude, :_destroy, { imediacoes: [] }] }
      ]
      raw = ActionController::Parameters.new
      raw.deep_merge!(params[:habitation].permit(*permitted_keys)) if params[:habitation].present?
      raw.deep_merge!(params[:captacao].permit(*permitted_keys)) if params[:captacao].present?
      raw.permit!
      normalize_captacao_params(raw)
    end

    def normalize_captacao_params(raw)
      attrs = raw.to_h
      attrs["intake_step"] = attrs.delete("step") if attrs["step"].present?
      property_kind = attrs.delete("property_kind")
      mapped_category = case property_kind
                        when "sala_comercial" then "Sala Comercial"
                        when "terreno" then "Terreno"
                        when "residencial" then "Apartamento"
                        end
      attrs["categoria"] = mapped_category if mapped_category.present?
      if (modalidade = attrs.delete("modalidade")).present?
        attrs["status"] = modalidade.in?(%w[locacao_anual locacao_diaria]) ? "Aluguel" : "Venda"
      end
      attrs["proprietario"] = attrs.delete("proprietario_nome") if attrs["proprietario_nome"].present?
      attrs["proprietario_celular"] = attrs.delete("proprietario_telefone") if attrs["proprietario_telefone"].present?
      attrs["proprietario_codigo"] = attrs.delete("proprietario_cpf_cnpj") if attrs["proprietario_cpf_cnpj"].present?
      attrs["area_total_m2"] = attrs.delete("area_total") if attrs["area_total"].present?
      attrs["area_privativa_m2"] = attrs.delete("area_privativa") if attrs["area_privativa"].present?
      attrs["dormitorios_qtd"] = attrs.delete("dormitorios") if attrs["dormitorios"].present?
      attrs["suites_qtd"] = attrs.delete("suites") if attrs["suites"].present?
      attrs["demi_suites_qtd"] = attrs.delete("demi_suites") if attrs["demi_suites"].present?
      attrs["banheiros_qtd"] = attrs.delete("banheiros") if attrs["banheiros"].present?
      attrs["vagas_qtd"] = attrs.delete("vagas_garagem") if attrs["vagas_garagem"].present?
      attrs["andares_qtd"] = attrs.delete("andares_total") if attrs["andares_total"].present?
      attrs["aptos_andar"] = attrs.delete("aptos_por_andar") if attrs["aptos_por_andar"].present?
      attrs["valor_venda_formatted"] = attrs.delete("valor_venda") if attrs["valor_venda"].present?
      attrs["valor_locacao_formatted"] = attrs.delete("valor_locacao") if attrs["valor_locacao"].present?
      attrs["valor_condominio_formatted"] = attrs.delete("valor_condominio") if attrs["valor_condominio"].present?
      attrs["valor_iptu_formatted"] = attrs.delete("valor_iptu") if attrs["valor_iptu"].present?
      attrs["saldo_devedor_formatted"] = attrs.delete("saldo_devedor") if attrs["saldo_devedor"].present?
      attrs["nome_empreendimento"] = attrs.delete("edificio_nome") if attrs["edificio_nome"].present?
      attrs["bloco"] = attrs.delete("unidade_numero") if attrs["unidade_numero"].present?
      attrs["ocupacao_status"] = attrs.delete("ocupacao") if attrs["ocupacao"].present?
      attrs["estado_conservacao"] = attrs.delete("estado_imovel") if attrs["estado_imovel"].present?
      attrs["situacao"] = attrs.delete("situacao_imovel") if attrs["situacao_imovel"].present?
      attrs["observacoes_visitas"] = [attrs.delete("chaves_com"), attrs.delete("senha_imovel"), attrs.delete("senha_portaria"), attrs["observacoes_visitas"]].compact_blank.join(" | ")
      attrs["caracteristicas"] = attrs.delete("caracteristicas_imovel") if attrs["caracteristicas_imovel"].present?
      attrs["infra_estrutura"] = attrs.delete("caracteristicas_predio") if attrs["caracteristicas_predio"].present?
      attrs["aceita_permuta_answer"] = Array(attrs.delete("aceita_permuta")).include?("Sim") ? "sim" : "nao" if attrs.key?("aceita_permuta")
      attrs["aceita_parcelamento_flag"] = ActiveModel::Type::Boolean.new.cast(attrs["aceita_parcelamento_flag"]) if attrs.key?("aceita_parcelamento_flag")
      if attrs["aceita_parcelamento"].present?
        attrs["aceita_parcelamento_flag"] = attrs.delete("aceita_parcelamento") != "nao"
      end
      attrs["photos"] = attrs.delete("fotos") if attrs["fotos"].present?
      attrs["autorizacoes_venda"] = Array(attrs.delete("autorizacao_pdf")) if attrs["autorizacao_pdf"].present?
      address_keys = %w[zip_code street street_number neighborhood city state]
      if address_keys.any? { |key| attrs.key?(key) }
        attrs["address_attributes"] = {
          cep: attrs.delete("zip_code"),
          logradouro: attrs.delete("street"),
          numero: attrs.delete("street_number"),
          bairro: attrs.delete("neighborhood"),
          cidade: attrs.delete("city"),
          uf: attrs.delete("state")
        }.compact_blank
        attrs["address_attributes"]["id"] = @habitation.address.id if @habitation.address.present?
      end
      attrs.except("salas", "sacada", "terraco", "dependencia_empregada", "precisa_reforma", "distancia_praia", "cidade_permuta", "outras_taxas", "dias_visitas", "extras", "proprietario_cidade")
    end

    def sale_reason_options
      catalog_options = AttributeOption.where(context: "habitation", category: "sale_reason").order(:name).pluck(:name)
      habitation_options = if Habitation.column_names.include?("motivo_venda")
                             Habitation.where.not(motivo_venda: [nil, ""]).distinct.pluck(:motivo_venda)
                           else
                             []
                           end
      captacao_options = if defined?(Captacao) && Captacao.column_names.include?("motivo_venda")
                           Captacao.where.not(motivo_venda: [nil, ""]).distinct.pluck(:motivo_venda)
                         else
                           []
                         end

      (catalog_options + habitation_options + captacao_options).map { |reason| reason.to_s.strip }.reject(&:blank?).uniq.sort
    end
  end
end

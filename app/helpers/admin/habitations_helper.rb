module Admin::HabitationsHelper
  def admin_habitation_internal_path(habitation, return_to: nil)
    path_params = {}
    path_params[:return_to] = return_to if return_to.present?

    if admin_can_edit_habitation?(habitation)
      edit_admin_habitation_path(habitation, path_params)
    else
      admin_habitation_path(habitation, path_params)
    end
  end

  def admin_habitation_internal_action_label(habitation)
    admin_can_edit_habitation?(habitation) ? "Editar imóvel" : "Abrir cadastro"
  end

  def admin_habitation_catalog_card_path(habitation, ownership_scope:, intake_review:, return_to: nil)
    path_params = {}
    path_params[:return_to] = return_to if return_to.present?

    return admin_habitation_path(habitation, path_params) if ownership_scope.to_s == "all" && intake_review.blank?

    admin_habitation_internal_path(habitation, return_to: return_to)
  end

  def admin_habitation_catalog_action_label(habitation, ownership_scope:, intake_review:)
    return "Visualizar cadastro" if ownership_scope.to_s == "all" && intake_review.blank?

    admin_habitation_internal_action_label(habitation)
  end

  def admin_habitation_media_preview(attachment)
    image_classes = "rounded border w-100 h-100 object-fit-cover"

    if attachment.blob.representable?
      image_tag attachment.representation(resize_to_limit: [360, 360]),
        class: image_classes,
        loading: "lazy",
        decoding: "async"
    elsif attachment.blob.image?
      image_tag url_for(attachment),
        class: image_classes,
        loading: "lazy",
        decoding: "async"
    else
      content_tag :div, class: "rounded border w-100 h-100 bg-light text-muted d-flex flex-column align-items-center justify-content-center text-center p-2" do
        safe_join([
          content_tag(:i, "", class: "bi bi-file-earmark-zip fs-3 mb-2"),
          content_tag(:span, attachment.filename.to_s, class: "small fw-semibold text-break")
        ])
      end
    end
  end

  def admin_can_edit_habitation?(habitation)
    return false unless current_admin_user && habitation

    cache_key = habitation.id || habitation.object_id
    @admin_habitation_edit_permissions ||= {}
    return @admin_habitation_edit_permissions[cache_key] if @admin_habitation_edit_permissions.key?(cache_key)

    @admin_habitation_edit_permissions[cache_key] =
      current_admin_user.owns_all?(:imoveis) ||
      habitation.admin_user_id == current_admin_user.id ||
      habitation_assigned_to_current_user?(habitation) ||
      habitation_matches_current_broker_name?(habitation)
  end

  def habitation_assigned_to_current_user?(habitation)
    if habitation.broker_assignments.loaded?
      habitation.broker_assignments.any? { |assignment| assignment.admin_user_id == current_admin_user.id }
    else
      habitation.broker_assignments.exists?(admin_user_id: current_admin_user.id)
    end
  end

  def habitation_matches_current_broker_name?(habitation)
    broker_name = current_admin_user.name.to_s.strip.downcase
    broker_name.present? && habitation.corretor_nome.to_s.downcase.include?(broker_name)
  end
end

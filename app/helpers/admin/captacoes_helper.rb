module Admin::CaptacoesHelper
  def captacao_feature_options(*groups)
    options = groups.flatten.compact_blank.map { |value| captacao_feature_label(value) }.compact_blank
    options.index_by { |label| captacao_feature_key(label) }.values.sort_by { |label| captacao_feature_key(label) }
  end

  def captacao_feature_selected?(selected_values, label)
    selected_keys = Array(selected_values).map { |value| captacao_feature_key(captacao_feature_label(value) || value) }
    selected_keys.include?(captacao_feature_key(label))
  end

  def captacao_workflow_status_label(captacao)
    return "Publicada" if captacao.published_on_site? || captacao.intake_published?
    return "Liberar para site" if captacao.intake_admin_approved?
    return "Pendente de revisão" if captacao.intake_submitted_for_admin_review?
    return "Devolvida" if captacao.intake_returned_to_broker?

    "Rascunho"
  end

  def captacao_workflow_status_badge_class(captacao)
    return "bg-success" if captacao.published_on_site? || captacao.intake_published?
    return "bg-success-subtle text-success border" if captacao.intake_admin_approved?
    return "bg-info-subtle text-info border" if captacao.intake_submitted_for_admin_review?
    return "bg-danger" if captacao.intake_returned_to_broker?

    "bg-warning text-dark"
  end

  def captacao_workflow_action_label(captacao)
    return "Ver publicação" if captacao.published_on_site? || captacao.intake_published?
    return "Liberar site" if captacao.intake_admin_approved?
    return "Ver revisão" if captacao.intake_submitted_for_admin_review?
    return "Corrigir cadastro" if captacao.intake_returned_to_broker?

    "Continuar cadastro"
  end

  def captacao_workflow_action_path(captacao)
    if captacao.intake_draft? || captacao.intake_returned_to_broker?
      edit_admin_captacao_path(captacao)
    else
      admin_captacao_path(captacao)
    end
  end

  private

  def captacao_feature_label(value)
    raw = value.to_s.strip
    return if raw.blank?

    label = AttributeOptions::HabitationFeatureNormalizer.label(raw)
    return label if label.present? && label != raw.tr("_", " ").squish
    return if raw.match?(/\A[a-z0-9]+(?:_[a-z0-9]+)+\z/)

    raw.squish
  end

  def captacao_feature_key(value)
    AttributeOptions::HabitationFeatureNormalizer.key(value)
  end
end

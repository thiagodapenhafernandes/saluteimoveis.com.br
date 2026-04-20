require "set"

class LoftSyncJob < ApplicationJob
  queue_as :default

  def perform(mode: "full", batch_size: nil, triggered_by_id: nil)
    lock_service = Loft::SyncLockService.new(
      lock_key: "loft_sync_lock",
      lease_seconds: ENV.fetch("LOFT_SYNC_LOCK_LEASE_SECONDS", "5400")
    )
    lock_owner = lock_service.acquire
    status_service = Loft::SyncStatusService.new

    unless lock_owner.present?
      status_service.mark_skipped!(mode: mode, message: "Loft sync ignorado: já existe uma sincronização em andamento.")
      return
    end

    status_service.mark_processing!(mode: mode, message: "Sincronização Loft iniciada.", progress: 5)

    host = Setting.get("loft_host").to_s.presence || ENV.fetch("VISTA_HOST", "")
    token = Setting.get("loft_token").to_s.presence || ENV.fetch("VISTA_KEY", "")
    raise "Host Loft não configurado." if host.blank?
    raise "Token Loft não configurado." if token.blank?

    normalized_mode = mode.to_s == "batch" ? "batch" : "full"
    size = batch_size.to_i.positive? ? batch_size.to_i : Setting.get("loft_sync_batch_size", "100").to_i
    listing = Loft::PropertyCodesService.new(host: host, token: token).call(mode: normalized_mode, batch_size: size)
    codes = listing[:codes]
    categorias = listing[:categorias] || {}
    parent_codes = listing[:parent_codes] || Set.new

    if codes.blank?
      status_service.mark_skipped!(mode: normalized_mode, message: "Nenhum imóvel encontrado para sincronização.")
      return
    end

    # Empreendimentos/pais primeiro (validação de codigo_empreendimento_must_exist em unidades filhas).
    # É pai se Categoria="Empreendimento" OU se algum outro imóvel referencia este código.
    empreendimentos, unidades = codes.partition do |c|
      categorias[c].to_s.casecmp("Empreendimento").zero? || parent_codes.include?(c)
    end
    codes = empreendimentos + unidades

    dwv_codes = Habitation.where(codigo: codes, imovel_dwv: "Sim").pluck(:codigo).map(&:to_s).to_set

    created = 0
    updated = 0
    errors_count = 0
    skipped_dwv = 0
    processed = 0
    total = codes.size

    codes.each do |code|
      if dwv_codes.include?(code.to_s)
        skipped_dwv += 1
        processed += 1
        progress = total.positive? ? ((processed.to_f / total.to_f) * 100).round : 100
        status_service.update_progress!(progress: progress, message: "Sincronizando imóveis Loft (#{processed}/#{total})...")
        next
      end

      result = SyncPropertyService.new(
        code,
        host: host,
        token: token,
        force_empreendimento: parent_codes.include?(code)
      ).perform
      created += 1 if result[:created]
      updated += 1 if result[:updated]
      errors_count += 1 unless result[:success]
      processed += 1
      progress = total.positive? ? ((processed.to_f / total.to_f) * 100).round : 100
      status_service.update_progress!(progress: progress, message: "Sincronizando imóveis Loft (#{processed}/#{total})...")
    rescue => e
      errors_count += 1
      processed += 1
      Rails.logger.error("[LoftSyncJob] codigo=#{code} erro=#{e.message}")
    end

    message = [
      "Loft sync (#{normalized_mode}) concluído",
      "processados=#{processed}",
      "criados=#{created}",
      "atualizados=#{updated}",
      "pulados_dwv=#{skipped_dwv}",
      "erros=#{errors_count}",
      "total_remoto=#{listing[:remote_total]}",
      ("triggered_by=#{triggered_by_id}" if triggered_by_id.present?)
    ].compact.join(" | ")

    status_service.mark_completed!(
      mode: normalized_mode,
      message: message,
      stats: {
        processed: processed,
        created: created,
        updated: updated,
        skipped_dwv: skipped_dwv,
        errors_count: errors_count,
        remote_total: listing[:remote_total]
      }
    )
  rescue => e
    status_service&.mark_failed!(mode: mode, message: "Loft sync falhou: #{e.message}")
    raise e
  ensure
    lock_service&.release(lock_owner)
  end
end

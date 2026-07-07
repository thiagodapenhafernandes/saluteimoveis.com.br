class DwvIncrementalSyncJob < ApplicationJob
  queue_as :dwv

  def perform
    unless dwv_ready?
      Rails.logger.info("[DWV] Sync incremental ignorado: integração desativada ou sem token.")
      return
    end

    lock_service = Dwv::SyncLockService.new(lease_seconds: ENV.fetch("DWV_INCREMENTAL_LOCK_LEASE_SECONDS", "900"))
    lock_owner = lock_service.acquire

    if lock_owner.blank?
      Rails.logger.info("[DWV] Sync incremental ignorado: já existe uma sincronização em andamento.")
      return
    end

    result = Dwv::SyncRunnerService.new.call(mode: "incremental")
    message = [
      "DWV sync incremental concluído",
      "importados=#{result[:imported]}",
      "excluidos=#{result[:deleted]}",
      "erros=#{result[:errors_count]}"
    ].join(" | ")

    Setting.set("dwv_incremental_last_run_at", Time.current.iso8601, "Última execução do sync incremental DWV")
    Setting.set("dwv_incremental_last_message", message, "Resumo da última execução incremental DWV")
    Rails.logger.info("[DWV] #{message}")
  rescue => e
    Setting.set("dwv_incremental_last_message", "DWV sync incremental falhou: #{e.message}", "Resumo da última execução incremental DWV")
    Rails.logger.error("[DWV] Sync incremental falhou: #{e.message}")
    raise e
  ensure
    lock_service&.release(lock_owner)
  end

  private

  def dwv_ready?
    Setting.get("dwv_enabled", "false") == "true" && Setting.get("dwv_api_token").to_s.present?
  end
end

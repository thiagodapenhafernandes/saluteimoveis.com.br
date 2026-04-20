module Vista
  # Progresso da sincronização Vista → AdminUser persistido em Settings para
  # sobreviver entre o worker (job) e os requests HTTP (polling do admin).
  #
  # Chaves:
  #   vista_agents_sync_status        — idle | processing | completed | failed
  #   vista_agents_sync_progress      — 0..100
  #   vista_agents_sync_message       — mensagem curta ("Página 3 de 8…")
  #   vista_agents_sync_stats         — JSON { processed, created, updated, errors, page, total_pages }
  #   vista_agents_sync_started_at    — ISO8601
  #   vista_agents_sync_finished_at   — ISO8601
  class SyncStatusService
    STATUS_KEY     = "vista_agents_sync_status".freeze
    PROGRESS_KEY   = "vista_agents_sync_progress".freeze
    MESSAGE_KEY    = "vista_agents_sync_message".freeze
    STATS_KEY      = "vista_agents_sync_stats".freeze
    STARTED_KEY    = "vista_agents_sync_started_at".freeze
    FINISHED_KEY   = "vista_agents_sync_finished_at".freeze

    def mark_processing!(message:, stats: {})
      Setting.set(STATUS_KEY, "processing")
      Setting.set(PROGRESS_KEY, "0")
      Setting.set(MESSAGE_KEY, message.to_s)
      Setting.set(STATS_KEY, stats.to_json)
      Setting.set(STARTED_KEY, Time.current.iso8601)
      Setting.set(FINISHED_KEY, "")
    end

    def update_progress!(progress:, message: nil, stats: nil)
      Setting.set(PROGRESS_KEY, progress.to_i.clamp(0, 100).to_s)
      Setting.set(MESSAGE_KEY, message.to_s) if message.present?
      Setting.set(STATS_KEY, stats.to_json) if stats.present?
    end

    def mark_completed!(message:, stats: {})
      Setting.set(STATUS_KEY, "completed")
      Setting.set(PROGRESS_KEY, "100")
      Setting.set(MESSAGE_KEY, message.to_s)
      Setting.set(STATS_KEY, stats.to_json)
      Setting.set(FINISHED_KEY, Time.current.iso8601)
    end

    def mark_failed!(message:, stats: {})
      Setting.set(STATUS_KEY, "failed")
      Setting.set(MESSAGE_KEY, message.to_s)
      Setting.set(STATS_KEY, stats.to_json)
      Setting.set(FINISHED_KEY, Time.current.iso8601)
    end

    def snapshot
      raw_stats = Setting.get(STATS_KEY, "{}").to_s
      stats = JSON.parse(raw_stats) rescue {}
      {
        status:       Setting.get(STATUS_KEY, "idle"),
        progress:     Setting.get(PROGRESS_KEY, "0").to_i,
        message:      Setting.get(MESSAGE_KEY, ""),
        stats:        stats,
        started_at:   parse_time(Setting.get(STARTED_KEY, "")),
        finished_at:  parse_time(Setting.get(FINISHED_KEY, ""))
      }
    end

    private

    def parse_time(str)
      return nil if str.to_s.empty?
      Time.iso8601(str) rescue nil
    end
  end
end

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "propertyProgressValue",
    "propertiesWithPhotos",
    "totalProperties",
    "pendingProperties",
    "migratedImages",
    "imageProgress",
    "workerBadge",
    "workerPid",
    "globalProgressBar",
    "globalProgressPercent",
    "executionPanel",
    "executionProgressBar",
    "executionProgressPercent",
    "executionLabel",
    "executionDetail",
    "executionStatus",
    "executionCycle",
    "executionSynced",
    "executionSkipped",
    "executionFailed",
    "executionRemaining",
    "executionPropertiesAdded",
    "executionImagesAdded",
    "executionLastRunAt",
    "summaryTotalProperties",
    "summaryPropertiesWithPhotos",
    "summaryPendingProperties",
    "summaryPublicPendingProperties",
    "summaryPublicVistaFirstProperties",
    "summaryTotalSourceImages",
    "cursorLastId",
    "failedProperties",
    "latestAttachmentAt",
    "syncButton",
    "retryButton"
  ]

  static values = {
    url: String,
    runningInterval: { type: Number, default: 2500 },
    idleInterval: { type: Number, default: 10000 }
  }

  connect() {
    this.refresh()
  }

  disconnect() {
    this.stop()
  }

  refresh() {
    if (!this.hasUrlValue || document.hidden) {
      this.schedule(this.idleIntervalValue)
      return
    }

    fetch(this.urlWithCacheBust(), { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) throw new Error("status_request_failed")
        return response.json()
      })
      .then((status) => {
        this.render(status)
        this.schedule(status.worker?.running ? this.runningIntervalValue : this.idleIntervalValue)
      })
      .catch(() => this.schedule(this.idleIntervalValue))
  }

  stop() {
    if (!this.timer) return

    clearTimeout(this.timer)
    this.timer = null
  }

  schedule(interval) {
    this.stop()
    this.timer = setTimeout(() => this.refresh(), interval)
  }

  render(status) {
    const execution = status.execution || {}

    this.setText(this.propertyProgressValueTarget, this.percent(status.property_progress))
    this.setText(this.propertiesWithPhotosTarget, this.integer(status.properties_with_photos))
    this.setText(this.totalPropertiesTarget, this.integer(status.total_properties))
    this.setText(this.pendingPropertiesTarget, this.integer(status.pending_properties))
    this.setText(this.migratedImagesTarget, this.integer(status.migrated_images))
    this.setText(this.imageProgressTarget, this.percent(status.image_progress))
    this.setText(this.globalProgressPercentTarget, this.percent(status.property_progress))
    this.setProgress(this.globalProgressBarTarget, status.property_progress)

    this.renderWorker(status.worker || {})
    this.renderExecution(execution)
    this.renderSummary(status)
    this.renderControls(status)
  }

  renderWorker(worker) {
    if (this.hasWorkerBadgeTarget) {
      this.workerBadgeTarget.textContent = worker.status || "N/D"
      this.workerBadgeTarget.classList.toggle("bg-success", !!worker.running)
      this.workerBadgeTarget.classList.toggle("bg-danger", !worker.running)
    }

    this.setText(this.workerPidTarget, worker.pid ? `PID ${worker.pid}` : "Sem PID registrado")
  }

  renderExecution(execution) {
    const progress = Number(execution.progress || 0)
    this.setProgress(this.executionProgressBarTarget, progress)
    this.setText(this.executionProgressPercentTarget, this.percent(progress))
    this.setText(this.executionLabelTarget, execution.label || "Aguardando execução")
    this.setText(this.executionStatusTarget, execution.running ? "Rodando" : "Parado")
    this.setText(this.executionCycleTarget, this.integer(execution.cycle || 0))
    this.setText(this.executionSyncedTarget, this.integer(execution.synced || 0))
    this.setText(this.executionSkippedTarget, this.integer(execution.skipped || 0))
    this.setText(this.executionFailedTarget, this.integer(execution.failed || 0))
    this.setText(this.executionRemainingTarget, this.integer(execution.remaining || 0))
    this.setText(this.executionPropertiesAddedTarget, this.integer(execution.properties_added || 0))
    this.setText(this.executionImagesAddedTarget, this.integer(execution.images_added || 0))
    this.setText(this.executionLastRunAtTarget, this.dateTime(execution.last_run_at) || "N/D")

    const current = this.integer(execution.current || 0)
    const total = this.integer(execution.total || 0)
    this.setText(this.executionDetailTarget, `${current} de ${total}`)

    if (this.hasExecutionProgressBarTarget) {
      this.executionProgressBarTarget.classList.toggle("progress-bar-animated", !!execution.running)
      this.executionProgressBarTarget.classList.toggle("progress-bar-striped", !!execution.running)
    }
  }

  renderSummary(status) {
    this.setText(this.summaryTotalPropertiesTarget, this.integer(status.total_properties))
    this.setText(this.summaryPropertiesWithPhotosTarget, this.integer(status.properties_with_photos))
    this.setText(this.summaryPendingPropertiesTarget, this.integer(status.pending_properties))
    this.setText(this.summaryPublicPendingPropertiesTarget, this.integer(status.public_pending_properties))
    this.setText(this.summaryPublicVistaFirstPropertiesTarget, this.integer(status.public_vista_first_properties))
    this.setText(this.summaryTotalSourceImagesTarget, this.integer(status.total_source_images))
    this.setText(this.cursorLastIdTarget, status.cursor_last_id || "N/D")
    this.setText(this.failedPropertiesTarget, this.integer(status.failed_properties))
    this.setText(this.latestAttachmentAtTarget, this.dateTime(status.latest_attachment_at) || "N/D")
  }

  renderControls(status) {
    const running = !!status.worker?.running

    if (this.hasSyncButtonTarget) this.syncButtonTarget.disabled = running
    if (this.hasRetryButtonTarget) this.retryButtonTarget.disabled = running || Number(status.failed_properties || 0) === 0
  }

  setText(target, value) {
    if (!target) return
    target.textContent = value
  }

  setProgress(target, value) {
    if (!target) return

    const progress = Math.max(0, Math.min(100, Number(value || 0)))
    target.style.width = `${progress}%`
    target.setAttribute("aria-valuenow", progress.toString())
  }

  integer(value) {
    return new Intl.NumberFormat("pt-BR").format(Number(value || 0))
  }

  percent(value) {
    return `${new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(Number(value || 0))}%`
  }

  dateTime(value) {
    if (!value) return null

    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return null

    return date.toLocaleString("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    })
  }

  urlWithCacheBust() {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("_ts", Date.now().toString())
    return url.toString()
  }
}

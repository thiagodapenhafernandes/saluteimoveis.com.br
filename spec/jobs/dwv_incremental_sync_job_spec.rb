require "rails_helper"

RSpec.describe DwvIncrementalSyncJob do
  describe "#perform" do
    it "skips when the integration is disabled" do
      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("false")

      expect(Dwv::SyncRunnerService).not_to receive(:new)

      described_class.perform_now
    end

    it "skips when another sync holds the lock" do
      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      lock_service = instance_double(Dwv::SyncLockService, acquire: nil, release: nil)
      allow(Dwv::SyncLockService).to receive(:new).and_return(lock_service)

      expect(Dwv::SyncRunnerService).not_to receive(:new)

      described_class.perform_now
    end

    it "runs the incremental sync, stamps settings and releases the lock" do
      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      lock_service = instance_double(Dwv::SyncLockService, acquire: "owner-token", release: true)
      allow(Dwv::SyncLockService).to receive(:new).and_return(lock_service)
      runner = instance_double(Dwv::SyncRunnerService)
      allow(Dwv::SyncRunnerService).to receive(:new).and_return(runner)
      allow(runner).to receive(:call).with(mode: "incremental").and_return(
        { imported: 2, deleted: 1, errors_count: 0, errors_by_reason: {} }
      )
      allow(Setting).to receive(:set)

      described_class.perform_now

      expect(Setting).to have_received(:set).with("dwv_incremental_last_run_at", anything, anything)
      expect(Setting).to have_received(:set).with(
        "dwv_incremental_last_message",
        a_string_including("importados=2").and(a_string_including("excluidos=1")),
        anything
      )
      expect(lock_service).to have_received(:release).with("owner-token")
    end

    it "records the failure message and releases the lock when the sync raises" do
      allow(Setting).to receive(:get).and_call_original
      allow(Setting).to receive(:get).with("dwv_enabled", "false").and_return("true")
      allow(Setting).to receive(:get).with("dwv_api_token").and_return("token")
      lock_service = instance_double(Dwv::SyncLockService, acquire: "owner-token", release: true)
      allow(Dwv::SyncLockService).to receive(:new).and_return(lock_service)
      runner = instance_double(Dwv::SyncRunnerService)
      allow(Dwv::SyncRunnerService).to receive(:new).and_return(runner)
      allow(runner).to receive(:call).and_raise("boom")
      allow(Setting).to receive(:set)

      expect { described_class.perform_now }.to raise_error("boom")

      expect(Setting).to have_received(:set).with(
        "dwv_incremental_last_message",
        a_string_including("falhou"),
        anything
      )
      expect(lock_service).to have_received(:release).with("owner-token")
    end
  end
end

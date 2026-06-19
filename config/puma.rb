require 'dotenv/load'

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

if ENV.fetch("RAILS_ENV", "development") == "production"
  # Deploy por symlink: aponta o diretório para o "current" para que o restart
  # quente (SIGUSR2) siga o symlink e carregue a nova release (deploy sem downtime).
  app_dir = ENV.fetch("PUMA_DIRECTORY", "/home/salute/deploy/current")
  directory app_dir if Dir.exist?(app_dir)

  workers ENV.fetch("WEB_CONCURRENCY", 3)
  preload_app!

  bind "tcp://127.0.0.1:9292"
  
  # pidfile "tmp/pids/puma.pid"
  # state_path "tmp/pids/puma.state"
  
  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
end

plugin :tmp_restart

require_relative "../application"
Rails.application.configure do
  app_host = ENV.fetch("APP_HOST", "pedeai.insilico.cloud")

  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")

  # The public endpoint is served through an HTTPS reverse proxy.
  config.hosts << app_host
  config.assume_ssl = ENV.fetch("RAILS_ASSUME_SSL", "true") == "true"
  config.force_ssl = ENV.fetch("RAILS_FORCE_SSL", "true") == "true"
  config.action_controller.default_url_options = { host: app_host, protocol: "https" }
end

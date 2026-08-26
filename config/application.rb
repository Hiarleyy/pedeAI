require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
Bundler.require(*Rails.groups)
module Pedeai
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "America/Sao_Paulo"
  end
end

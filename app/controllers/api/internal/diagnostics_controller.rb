module Api
  module Internal
    class DiagnosticsController < BaseController
      before_action -> { require_platform_permission!("diagnostics:read") }

      def show
        render json: {
          version: ENV.fetch("APP_VERSION", "development"),
          commit: ENV.fetch("SOURCE_COMMIT", "unknown"),
          built_at: ENV.fetch("BUILD_TIMESTAMP", "unknown"),
          services: { database: database_health, redis: redis_health }
        }
      end

      private

      def database_health
        ActiveRecord::Base.connection.select_value("SELECT 1") == 1 ? "healthy" : "unhealthy"
      rescue StandardError
        "unhealthy"
      end

      def redis_health
        Sidekiq.redis { |connection| connection.ping } == "PONG" ? "healthy" : "unhealthy"
      rescue StandardError
        "unhealthy"
      end
    end
  end
end

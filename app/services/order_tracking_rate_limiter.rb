class OrderTrackingRateLimiter
  WINDOW = 1.minute
  DEFAULT_LIMIT = 12

  class << self
    def allowed?(restaurant_slug:, ip:)
      key = "order-tracking:#{restaurant_slug}:#{ip.presence || 'unknown'}"
      attempts = Rails.cache.read(key).to_i
      return false if attempts >= limit

      Rails.cache.write(key, attempts + 1, expires_in: WINDOW)
      true
    end

    def limit
      ENV.fetch("ORDER_TRACKING_RATE_LIMIT", DEFAULT_LIMIT).to_i
    end
  end
end

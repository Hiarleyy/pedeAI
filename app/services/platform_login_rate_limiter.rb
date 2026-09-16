class PlatformLoginRateLimiter
  LIMIT = 5
  WINDOW = 15.minutes

  def self.allowed?(email:, ip:)
    key = cache_key(email: email, ip: ip)
    attempts = Rails.cache.read(key).to_i
    Rails.cache.write(key, attempts + 1, expires_in: WINDOW)
    attempts < LIMIT
  end

  def self.reset!(email:, ip:)
    Rails.cache.delete(cache_key(email: email, ip: ip))
  end

  def self.cache_key(email:, ip:)
    "platform-login:#{Digest::SHA256.hexdigest("#{email.to_s.downcase}:#{ip}")}"
  end
end

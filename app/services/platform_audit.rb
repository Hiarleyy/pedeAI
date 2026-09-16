class PlatformAudit
  REDACTED_KEYS = /password|token|secret|authorization/i

  def self.record(action:, outcome:, actor: nil, target: nil, justification: nil, request: nil, actor_identifier: nil, details: {})
    PlatformAuditEvent.create!(
      platform_user: actor,
      actor_identifier: actor_identifier || actor&.email,
      action: action,
      target_type: target&.class&.name,
      target_id: target&.id,
      outcome: outcome,
      justification: justification,
      request_id: request&.request_id,
      ip_address: request&.remote_ip,
      details: redact(details)
    )
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.error("platform_audit_failed=#{error.class}")
    nil
  end

  def self.redact(value)
    case value
    when Hash
      value.to_h.each_with_object({}) { |(key, item), result| result[key] = key.to_s.match?(REDACTED_KEYS) ? "[REDACTED]" : redact(item) }
    when Array then value.map { |item| redact(item) }
    else value
    end
  end
end

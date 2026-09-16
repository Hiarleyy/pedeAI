require "test_helper"

class PlatformAuditEventTest < ActiveSupport::TestCase
  test "audit events are append-only and redact secrets" do
    event = PlatformAudit.record(action: "test.action", outcome: "success", details: { password: "secret", nested: { token: "raw", safe: "value" } })
    assert_equal "[REDACTED]", event.details["password"]
    assert_equal "[REDACTED]", event.details.dig("nested", "token")
    assert_equal "value", event.details.dig("nested", "safe")
    refute event.update(action: "changed")
    refute event.destroy
  end
end

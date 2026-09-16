module PlatformAuthenticatable
  extend ActiveSupport::Concern

  included { attr_reader :current_platform_user }

  private

  def authenticate_platform_user!
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence
    @current_platform_user = PlatformUser.find_signed(token, purpose: :platform_auth) if token
    return if @current_platform_user&.active?

    render json: { error: "unauthorized", messages: ["Platform authentication required"] }, status: :unauthorized
  end

  def require_platform_permission!(permission)
    return if current_platform_user&.allowed?(permission)

    PlatformAudit.record(action: "authorization.denied", outcome: "denied", actor: current_platform_user, request: request, details: { permission: permission })
    render json: { error: "forbidden", messages: ["Missing platform permission: #{permission}"] }, status: :forbidden
  end
end

module Api
  module Internal
    class SessionsController < ApplicationController
      def create
        credentials = params.require(:platform_user).permit(:email, :password)
        email = credentials[:email].to_s.strip.downcase
        unless PlatformLoginRateLimiter.allowed?(email: email, ip: request.remote_ip)
          PlatformAudit.record(action: "platform_session.create", outcome: "denied", actor_identifier: email, request: request, details: { reason: "rate_limited" })
          return render json: { error: "rate_limited", messages: ["Try again later"] }, status: :too_many_requests
        end

        user = PlatformUser.find_by(email: email)
        if user&.active? && user.authenticate(credentials[:password])
          PlatformLoginRateLimiter.reset!(email: email, ip: request.remote_ip)
          user.update_column(:last_login_at, Time.current)
          PlatformAudit.record(action: "platform_session.create", outcome: "success", actor: user, request: request)
          render json: { token: user.api_token, platform_user: user.as_json(except: :password_digest) }
        else
          PlatformAudit.record(action: "platform_session.create", outcome: "failure", actor: user, actor_identifier: email, request: request, details: { reason: user&.active? == false ? "inactive" : "invalid_credentials" })
          render json: { error: "invalid_credentials", messages: ["Invalid email or password"] }, status: :unauthorized
        end
      end
    end
  end
end

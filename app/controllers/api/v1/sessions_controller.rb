module Api
  module V1
    class SessionsController < ApplicationController
      def create
        credentials = params.require(:user).permit(:email, :password)
        user = User.find_by(email: credentials[:email].to_s.strip.downcase)
        if user&.authenticate(credentials[:password])
          render json: { token: user.api_token, user: user.as_json(except: %i[password_digest]) }
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end
    end
  end
end

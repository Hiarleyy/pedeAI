module Api
  module V1
    class UsersController < ApplicationController
      include Authenticatable
      before_action :resolve_restaurant!
      before_action :authenticate_user!
      before_action :authorize_restaurant!

      def index
        require_permission!("users:read") if current_user.funcionario?
        return if performed?

        render json: current_restaurant.users.as_json(except: :password_digest)
      end

      def create
        require_role!(:admin)
        return if performed?

        user = current_restaurant.users.new(user_params)
        return forbidden("superAdmin só pode ser criado junto com o restaurante") if user.super_admin?
        return forbidden("admin só pode criar funcionários") if current_user.admin? && !user.funcionario?

        user.save ? render(json: user.as_json(except: :password_digest), status: :created) : render_errors(user)
      end

      def update
        user = current_restaurant.users.find(params[:id])
        authorize_user_change!(user)
        return if performed?
        return forbidden("admin só pode manter funcionários") if current_user.admin? && user_params[:role].present? && user_params[:role] != "funcionario"
        return forbidden("superAdmin só pode ser criado junto com o restaurante") if !user.super_admin? && user_params[:role] == "superAdmin"

        user.update(user_params) ? render(json: user.as_json(except: :password_digest)) : render_errors(user)
      end

      def destroy
        user = current_restaurant.users.find(params[:id])
        return render(json: { error: "invalid_request", messages: ["não é possível excluir a própria conta"] }, status: :unprocessable_entity) if user == current_user

        authorize_user_change!(user)
        return if performed?

        user.destroy!
        head :no_content
      end

      private

      def authorize_user_change!(user)
        return if current_user.super_admin? && user == current_user
        return forbidden("Usuário não pode ser gerenciado") if user.super_admin?
        return if current_user.super_admin?
        return if current_user.admin? && user.funcionario? && user != current_user

        forbidden("Usuário não pode ser gerenciado")
      end

      def forbidden(message)
        render json: { error: "forbidden", messages: [message] }, status: :forbidden
      end

      def user_params = params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, permissions: {})
    end
  end
end

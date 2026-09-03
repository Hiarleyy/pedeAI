module Api
  module V1
    class UsersController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!

      def index
        restaurant = accessible_restaurant
        require_permission!("users:read") if current_user.funcionario?
        return if performed?
        render json: User.where(restaurant: restaurant).as_json(except: :password_digest)
      end

      def create
        restaurant = accessible_restaurant
        require_role!(:admin)
        return if performed?
        user = User.new(user_params)
        if user.super_admin?
          return render json: { error: "forbidden", message: "superAdmin só pode ser criado junto com o restaurante" }, status: :forbidden
        end
        if current_user.admin? && user.role != "funcionario"
          return render json: { error: "forbidden", message: "admin só pode criar funcionários" }, status: :forbidden
        end
        user.restaurant = restaurant
        user.save ? render(json: user.as_json(except: :password_digest), status: :created) : render_errors(user)
      end

      def update
        user = User.find(params[:id])
        authorize_user_change!(user)
        return if performed?
        if current_user.admin? && user_params[:role].present? && user_params[:role] != "funcionario"
          return render json: { error: "forbidden", message: "admin só pode manter funcionários" }, status: :forbidden
        end
        if !user.super_admin? && user_params[:role] == "superAdmin"
          return render json: { error: "forbidden", message: "superAdmin só pode ser criado junto com o restaurante" }, status: :forbidden
        end
        user.update(user_params) ? render(json: user.as_json(except: :password_digest)) : render_errors(user)
      end

      def destroy
        user = User.find(params[:id])
        return render json: { error: "invalid_request", message: "não é possível excluir a própria conta" }, status: :unprocessable_entity if user == current_user
        authorize_user_change!(user)
        return if performed?
        user.destroy! ? head(:no_content) : render_errors(user)
      end

      private

      def authorize_user_change!(user)
        return render(json: { error: "forbidden" }, status: :forbidden) if user.restaurant_id != current_user.restaurant_id
        return if current_user.super_admin? && user == current_user
        return render(json: { error: "forbidden" }, status: :forbidden) if user.super_admin?
        return if current_user.super_admin?
        return if current_user.admin? && user.funcionario? && user != current_user

        render json: { error: "forbidden" }, status: :forbidden
      end

      def user_params = params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, permissions: {})
    end
  end
end

module Authenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user, :current_restaurant
  end

  private

  def authenticate_user!
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence
    @current_user = User.find_signed(token, purpose: :api_auth) if token
    return if @current_user

    render json: { error: "unauthorized", messages: ["Authentication required"] }, status: :unauthorized
  end

  def require_role!(*roles)
    return if current_user&.role.in?(roles.map(&:to_s)) || current_user&.super_admin?

    render json: { error: "forbidden", messages: ["Insufficient role"] }, status: :forbidden
  end

  def require_permission!(permission)
    return if current_user&.allowed?(permission)

    render json: { error: "forbidden", messages: ["Missing permission: #{permission}"], permission: permission }, status: :forbidden
  end

  def resolve_restaurant!
    @current_restaurant = Restaurant.find_by!(slug: params.require(:restaurant_slug))
  end

  def authorize_restaurant!
    return if current_user&.restaurant_id == current_restaurant&.id

    raise ActiveRecord::RecordNotFound
  end
end

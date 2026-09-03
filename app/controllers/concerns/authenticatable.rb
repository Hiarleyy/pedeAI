module Authenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user
  end

  private

  def authenticate_user!
    token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence
    @current_user = User.find_signed(token, purpose: :api_auth) if token
    return if @current_user

    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def require_role!(*roles)
    return if current_user&.role.in?(roles.map(&:to_s)) || current_user&.super_admin?

    render json: { error: "forbidden" }, status: :forbidden
  end

  def require_permission!(permission)
    return if current_user&.allowed?(permission)

    render json: { error: "forbidden", permission: permission }, status: :forbidden
  end

  def accessible_restaurant
    restaurant = if params[:restaurant_slug].present?
                   Restaurant.find_by!(slug: params[:restaurant_slug])
                 elsif (restaurant_id = params[:restaurant_id] || params[:id]).present?
                   Restaurant.find_by(id: restaurant_id) || Restaurant.find_by!(slug: restaurant_id)
                 else
                   current_user.restaurant
                 end

    return restaurant if restaurant && current_user.restaurant_id == restaurant.id

    raise ActiveRecord::RecordNotFound
  end
end


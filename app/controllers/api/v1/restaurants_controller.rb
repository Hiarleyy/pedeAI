module Api
  module V1
    class RestaurantsController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!, except: %i[create show]

      def index
        render json: [current_user.restaurant]
      end

      def show
        restaurant = Restaurant.find_by(id: params[:id]) || Restaurant.find_by!(slug: params[:id])
        render json: restaurant
      end

      def create
        restaurant = Restaurant.new(restaurant_params)
        super_admin = restaurant.users.build(super_admin_params.merge(role: "superAdmin", permissions: {}))

        Restaurant.transaction do
          restaurant.save!
          super_admin.save!
        end

        render json: {
          restaurant: restaurant,
          super_admin: super_admin.as_json(except: :password_digest)
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_errors(error.record)
      end

      def update
        restaurant = accessible_restaurant
        require_role!(:admin)
        return if performed?

        restaurant.update(settings_params) ? render(json: restaurant) : render_errors(restaurant)
      end

      private

      def restaurant_params = params.require(:restaurant).permit(:name, :slug, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color)
      def settings_params = params.require(:restaurant).permit(:name, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color)
      def super_admin_params = params.require(:super_admin).permit(:name, :email, :password, :password_confirmation)
    end
  end
end


module Api
  module V1
    class RestaurantsController < ApplicationController
      include Authenticatable
      before_action :resolve_restaurant!, only: %i[show update]
      before_action :authenticate_user!, only: :update
      before_action :authorize_restaurant!, only: :update

      def show
        render json: current_restaurant
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
      end

      def update
        require_role!(:admin)
        return if performed?

        current_restaurant.update(settings_params) ? render(json: current_restaurant) : render_errors(current_restaurant)
      end

      private

      def restaurant_params = params.require(:restaurant).permit(:name, :slug, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color, :font_family, menu_information: {})
      def settings_params = params.require(:restaurant).permit(:name, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color, :font_family, menu_information: {})
      def super_admin_params = params.require(:super_admin).permit(:name, :email, :password, :password_confirmation)
    end
  end
end

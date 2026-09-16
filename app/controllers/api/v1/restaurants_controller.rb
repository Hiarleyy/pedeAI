module Api
  module V1
    class RestaurantsController < ApplicationController
      include Authenticatable
      before_action :resolve_restaurant!, only: %i[show update]
      before_action :authenticate_user!, only: :update
      before_action :authorize_restaurant!, only: :update
      before_action :require_active_restaurant!, only: :update

      def show
        render json: current_restaurant
      end

      def update
        require_role!(:admin)
        return if performed?

        current_restaurant.update(settings_params) ? render(json: current_restaurant) : render_errors(current_restaurant)
      end

      private

      def settings_params = params.require(:restaurant).permit(:name, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color, :font_family, menu_information: {})
    end
  end
end

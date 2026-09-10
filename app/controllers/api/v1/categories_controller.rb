module Api
  module V1
    class CategoriesController < ApplicationController
      include Authenticatable
      before_action :resolve_restaurant!
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action :authorize_restaurant!, only: %i[create update destroy]
      before_action -> { require_permission!("categories:write") }, only: %i[create update destroy]

      def index
        render json: current_restaurant.categories.order(:position, :name)
      end

      def show
        render json: current_restaurant.categories.find(params[:id])
      end

      def create
        category = current_restaurant.categories.new(category_params)
        category.save ? render(json: category, status: :created) : render_errors(category)
      end

      def update
        category = current_restaurant.categories.find(params[:id])
        category.update(category_params) ? render(json: category) : render_errors(category)
      end

      def destroy
        category = current_restaurant.categories.find(params[:id])
        category.destroy ? head(:no_content) : render_errors(category)
      end

      private

      def category_params = params.require(:category).permit(:name, :description, :position)
    end
  end
end

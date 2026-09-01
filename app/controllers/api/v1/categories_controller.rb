module Api
  module V1
    class CategoriesController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action -> { require_permission!("categories:write") }, only: %i[create update destroy]

      def index
        scope = Category.order(:name)
        scope = scope.where(restaurant: Restaurant.find_by!(slug: params[:restaurant_slug])) if params[:restaurant_slug].present?
        render json: scope
      end
      def show
        scope = params[:restaurant_slug].present? ? Category.where(restaurant: Restaurant.find_by!(slug: params[:restaurant_slug])) : Category.all
        render json: scope.find(params[:id])
      end
      def create
        category = Category.new(category_params)
        category.restaurant = accessible_restaurant if params[:restaurant_slug].present?
        category.restaurant = current_user.restaurant unless params[:restaurant_slug].present?
        category.save ? render(json: category, status: :created) : render_errors(category)
      end
      def update
        category = manageable_scope(Category).find(params[:id])
        category.update(category_params) ? render(json: category) : render_errors(category)
      end
      def destroy
        category = manageable_scope(Category).find(params[:id])
        category.destroy ? head(:no_content) : render_errors(category)
      end
      private
      def category_params = params.require(:category).permit(:name, :description, :position)

      def manageable_scope(model)
        params[:restaurant_slug].present? ? model.where(restaurant: accessible_restaurant) : model.where(restaurant: current_user.restaurant)
      end
    end
  end
end

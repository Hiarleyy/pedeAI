module Api
  module V1
    class ProductsController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action -> { require_permission!("products:write") }, only: %i[create update destroy]

      def index
        scope = Product.includes(:category).order(:name)
        scope = scope.where(available: true) unless params[:restaurant_slug].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id]
        scope = scope.where(restaurant: Restaurant.find_by!(slug: params[:restaurant_slug])) if params[:restaurant_slug].present?
        render json: scope.as_json(include: :category)
      end
      def show
        scope = Product.includes(:category)
        scope = scope.where(restaurant: Restaurant.find_by!(slug: params[:restaurant_slug])) if params[:restaurant_slug].present?
        render json: scope.find(params[:id]).as_json(include: :category)
      end
      def create
        product = Product.new(product_params)
        product.restaurant = accessible_restaurant if params[:restaurant_slug].present?
        product.restaurant = current_user.restaurant unless params[:restaurant_slug].present?
        product.save ? render(json: product, status: :created) : render_errors(product)
      end
      def update
        product = manageable_scope(Product).find(params[:id])
        product.update(product_params) ? render(json: product) : render_errors(product)
      end
      def destroy
        product = manageable_scope(Product).find(params[:id])
        product.destroy ? head(:no_content) : render_errors(product)
      end
      private
      def product_params = params.require(:product).permit(:category_id, :name, :description, :price, :available, :image_url)

      def manageable_scope(model)
        params[:restaurant_slug].present? ? model.where(restaurant: accessible_restaurant) : model.where(restaurant: current_user.restaurant)
      end
    end
  end
end

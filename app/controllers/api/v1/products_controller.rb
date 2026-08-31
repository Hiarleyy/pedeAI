module Api
  module V1
    class ProductsController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action -> { require_permission!("products:write") }, only: %i[create update destroy]

      def index
        scope = Product.includes(:category).where(available: true).order(:name)
        scope = scope.where(category_id: params[:category_id]) if params[:category_id]
        scope = scope.where(restaurant: Restaurant.find_by!(slug: params[:restaurant_slug])) if params[:restaurant_slug].present?
        render json: scope.as_json(include: :category)
      end
      def show = render json: Product.includes(:category).find(params[:id]).as_json(include: :category)
      def create
        product = Product.new(product_params)
        product.restaurant = accessible_restaurant if params[:restaurant_slug].present?
        product.restaurant = current_user.restaurant unless current_user.super_admin?
        product.save ? render(json: product, status: :created) : render_errors(product)
      end
      def update
        product = manageable_scope(Product).find(params[:id])
        product.update(product_params) ? render(json: product) : render_errors(product)
      end
      def destroy
        manageable_scope(Product).find(params[:id]).destroy!
        head :no_content
      end
      private
      def product_params = params.require(:product).permit(:category_id, :name, :description, :price, :available, :image_url)

      def manageable_scope(model)
        params[:restaurant_slug].present? ? model.where(restaurant: accessible_restaurant) : (current_user.super_admin? ? model.all : model.where(restaurant: current_user.restaurant))
      end
    end
  end
end

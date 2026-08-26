module Api
  module V1
    class ProductsController < ApplicationController
      def index
        scope = Product.includes(:category).where(available: true).order(:name)
        scope = scope.where(category_id: params[:category_id]) if params[:category_id]
        render json: scope.as_json(include: :category)
      end
      def show = render json: Product.includes(:category).find(params[:id]).as_json(include: :category)
      def create
        product = Product.new(product_params)
        product.save ? render(json: product, status: :created) : render_errors(product)
      end
      def update
        product = Product.find(params[:id])
        product.update(product_params) ? render(json: product) : render_errors(product)
      end
      def destroy
        Product.find(params[:id]).destroy!
        head :no_content
      end
      private
      def product_params = params.require(:product).permit(:category_id, :name, :description, :price, :available, :image_url)
    end
  end
end

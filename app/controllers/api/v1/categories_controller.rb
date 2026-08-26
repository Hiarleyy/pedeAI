module Api
  module V1
    class CategoriesController < ApplicationController
      def index = render json: Category.order(:name)
      def show = render json: Category.find(params[:id])
      def create
        category = Category.new(category_params)
        category.save ? render(json: category, status: :created) : render_errors(category)
      end
      def update
        category = Category.find(params[:id])
        category.update(category_params) ? render(json: category) : render_errors(category)
      end
      def destroy
        category = Category.find(params[:id])
        category.destroy ? head(:no_content) : render_errors(category)
      end
      private
      def category_params = params.require(:category).permit(:name, :description, :position)
    end
  end
end

module Api
  module V1
    class MenuImportsController < ApplicationController
      include Authenticatable

      before_action :resolve_restaurant!
      before_action :authenticate_user!
      before_action :authorize_restaurant!
      before_action -> { require_permission!("categories:write") }
      before_action -> { require_permission!("products:write") }

      def create
        file = params[:file]
        unless file.respond_to?(:read) && file.size <= MenuJsonImport::MAX_FILE_SIZE
          render json: { error: "validation_error", messages: ["Envie um arquivo JSON de até #{MenuJsonImport::MAX_FILE_SIZE / 1.megabyte} MB"] }, status: :unprocessable_entity
          return
        end

        result = MenuJsonImport.new(current_restaurant, file.read).call
        if result.success?
          render json: { categories_created: result.categories_created, products_created: result.products_created }, status: :created
        else
          render json: { error: "validation_error", messages: result.errors }, status: :unprocessable_entity
        end
      end
    end
  end
end

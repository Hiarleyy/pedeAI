module Api
  module V1
    class ProductsController < ApplicationController
      PRODUCT_ATTRIBUTE_KEYS = %i[category_id name description price available image_url].freeze
      ADDON_ATTRIBUTE_KEYS = %i[id name price available].freeze
      VARIANT_ATTRIBUTE_KEYS = %i[id name price available position].freeze

      include Authenticatable
      before_action :resolve_restaurant!
      before_action :authenticate_admin_listing!, only: :index
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action :authorize_restaurant!, only: %i[create update destroy]
      before_action -> { require_permission!("products:write") }, only: %i[create update destroy]

      def index
        scope = current_restaurant.products.includes(:category, :addons, :variants).order(:name)
        scope = scope.where(available: true) unless administrative_listing?
        scope = scope.where(category: current_restaurant.categories.find(params[:category_id])) if params[:category_id].present?
        render json: scope.map { |product| serialized_product(product, administrative: administrative_listing?) }
      end

      def show
        product = current_restaurant.products.where(available: true).includes(:category, :addons, :variants).find(params[:id])
        render json: serialized_product(product)
      end

      def create
        stored_image = nil
        payload = normalized_product_payload
        product = current_restaurant.products.new(payload.fetch(:attributes))
        uploaded_image = payload[:image]
        image_storage.validate!(uploaded_image) if uploaded_image
        Product.transaction do
          product.save!
          product.replace_addons!(payload.fetch(:addons)) if payload[:addons_supplied]
          product.replace_variants!(payload.fetch(:variants)) if payload[:variants_supplied]
          if uploaded_image
            stored_image = image_storage.store!(uploaded_image, restaurant_id: current_restaurant.id, product_id: product.id)
            product.update_column(:image_url, stored_image.url)
          end
        end
        render json: serialized_product(product.reload, administrative: true), status: :created
      rescue ProductImageStorage::InvalidImage => error
        cleanup_failed_image(stored_image)
        render json: { error: "validation_error", messages: [error.message] }, status: :unprocessable_entity
      rescue Product::NestedValidationError => error
        cleanup_failed_image(stored_image)
        render json: { error: "validation_error", messages: error.messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        cleanup_failed_image(stored_image)
        render_errors(error.record)
      rescue StandardError
        cleanup_failed_image(stored_image)
        raise
      end

      def update
        stored_image = nil
        product = current_restaurant.products.find(params[:id])
        payload = normalized_product_payload
        uploaded_image = payload[:image]
        image_storage.validate!(uploaded_image) if uploaded_image
        previous_image_url = product.image_url
        Product.transaction do
          product.update!(payload.fetch(:attributes))
          product.replace_addons!(payload.fetch(:addons)) if payload[:addons_supplied]
          product.replace_variants!(payload.fetch(:variants)) if payload[:variants_supplied]
          if uploaded_image
            stored_image = image_storage.store!(uploaded_image, restaurant_id: current_restaurant.id, product_id: product.id)
            product.update_column(:image_url, stored_image.url)
          end
        end
        image_storage.delete_url!(previous_image_url) if uploaded_image
        render json: serialized_product(product.reload, administrative: true)
      rescue ProductImageStorage::InvalidImage => error
        cleanup_failed_image(stored_image)
        render json: { error: "validation_error", messages: [error.message] }, status: :unprocessable_entity
      rescue Product::NestedValidationError => error
        cleanup_failed_image(stored_image)
        render json: { error: "validation_error", messages: error.messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        cleanup_failed_image(stored_image)
        render_errors(error.record)
      rescue StandardError
        cleanup_failed_image(stored_image)
        raise
      end

      def destroy
        product = current_restaurant.products.find(params[:id])
        image_url = product.image_url
        if product.destroy
          image_storage.delete_url!(image_url)
          head :no_content
        else
          render_errors(product)
        end
      end

      private

      def authenticate_admin_listing!
        return unless administrative_listing?

        authenticate_user!
        return if performed?

        authorize_restaurant!
        require_permission!("products:write") unless performed?
      end

      def administrative_listing? = ActiveModel::Type::Boolean.new.cast(params[:admin])

      def normalized_product_payload
        raw = params.require(:product)
        permitted = raw.except(:addons, :variants).permit(*PRODUCT_ATTRIBUTE_KEYS, :image)
        {
          attributes: permitted.slice(*PRODUCT_ATTRIBUTE_KEYS),
          image: permitted[:image],
          addons_supplied: raw.key?(:addons),
          addons: normalize_collection(raw[:addons], "addons", ADDON_ATTRIBUTE_KEYS),
          variants_supplied: raw.key?(:variants),
          variants: normalize_collection(raw[:variants], "variants", VARIANT_ATTRIBUTE_KEYS)
        }
      end

      def normalize_collection(value, name, allowed_keys)
        return [] if value.nil?

        entries = case value
        when Array
          value
        when ActionController::Parameters, Hash
          indexed = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
          invalid_keys = indexed.keys.reject { |key| key.to_s.match?(/\A\d+\z/) }
          raise ActionController::BadRequest, "product.#{name} deve ser uma lista" if invalid_keys.any?
          indexed.sort_by { |key, _entry| key.to_i }.map(&:last)
        else
          raise ActionController::BadRequest, "product.#{name} deve ser uma lista"
        end

        entries.map do |entry|
          unless entry.is_a?(ActionController::Parameters) || entry.is_a?(Hash)
            raise ActionController::BadRequest, "product.#{name} deve conter objetos"
          end

          parameters = entry.is_a?(ActionController::Parameters) ? entry : ActionController::Parameters.new(entry)
          parameters.permit(*allowed_keys)
        end
      end

      def cleanup_failed_image(stored_image)
        image_storage.delete_url!(stored_image.url) if stored_image
      end

      def image_storage = @image_storage ||= ProductImageStorage.new

      def serialized_product(product, administrative: false)
        product.as_json(include: :category).merge("addons" => product.addons.select { |addon| administrative || addon.available? }.map(&:as_json), "variants" => product.variants.select { |variant| administrative || variant.available? }.sort_by(&:position).map(&:as_json))
      end
    end
  end
end

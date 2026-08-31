module Api
  module V1
    class OrdersController < ApplicationController
      include Authenticatable
      before_action :authenticate_user!, only: %i[index show update]
      before_action -> { require_permission!("orders:read") }, only: %i[index show]
      before_action -> { require_permission!("orders:update") }, only: :update

      def index
        orders = manageable_scope(Order).includes(order_items: :product).order(created_at: :desc)
        orders = orders.where(status: params[:status]) if params[:status].present?
        render json: orders.as_json(methods: :table_label, include: { order_items: { include: :product } })
      end
      def show = render json: Order.includes(order_items: :product).find(params[:id]).as_json(methods: :table_label, include: { order_items: { include: :product } })
      def create
        order = Order.new(order_params.except(:items))
        order.restaurant = accessible_restaurant if params[:restaurant_slug].present?
        order.order_items = Array(order_params[:items]).map do |item|
          product = if order.restaurant_id
                      Product.where(restaurant_id: order.restaurant_id).find(item[:product_id])
                    else
                      Product.find(item[:product_id])
                    end
          OrderItem.new(product: product, quantity: item[:quantity], unit_price: product.price)
        end
        order.save ? render(json: order.as_json(methods: :table_label, include: :order_items), status: :created) : render_errors(order)
      rescue ActionController::ParameterMissing => e
        render json: { error: "invalid_request", messages: [e.message] }, status: :bad_request
      end
      def update
        order = manageable_scope(Order).find(params[:id])
        order.update(status: params.require(:order).permit(:status)[:status]) ? render(json: order) : render_errors(order)
      end
      private
      def order_params = params.require(:order).permit(:customer_name, :customer_phone, :order_type, :delivery_address, :table_number, :payment_method, items: %i[product_id quantity])

      def manageable_scope(model)
        params[:restaurant_slug].present? ? model.where(restaurant: accessible_restaurant) : (current_user.super_admin? ? model.all : model.where(restaurant: current_user.restaurant))
      end
    end
  end
end

module Api
  module V1
    class OrdersController < ApplicationController
      def index
        orders = Order.includes(order_items: :product).order(created_at: :desc)
        orders = orders.where(status: params[:status]) if params[:status].present?
        render json: orders.as_json(methods: :table_label, include: { order_items: { include: :product } })
      end
      def show = render json: Order.includes(order_items: :product).find(params[:id]).as_json(methods: :table_label, include: { order_items: { include: :product } })
      def create
        order = Order.new(order_params.except(:items))
        order.order_items = Array(order_params[:items]).map do |item|
          product = Product.find(item[:product_id])
          OrderItem.new(product: product, quantity: item[:quantity], unit_price: product.price)
        end
        order.save ? render(json: order.as_json(methods: :table_label, include: :order_items), status: :created) : render_errors(order)
      rescue ActionController::ParameterMissing => e
        render json: { error: "invalid_request", messages: [e.message] }, status: :bad_request
      end
      def update
        order = Order.find(params[:id])
        order.update(status: params.require(:order).permit(:status)[:status]) ? render(json: order) : render_errors(order)
      end
      private
      def order_params = params.require(:order).permit(:customer_name, :customer_phone, :order_type, :delivery_address, :table_number, :payment_method, items: %i[product_id quantity])
    end
  end
end

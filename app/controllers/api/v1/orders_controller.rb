module Api
  module V1
    class OrdersController < ApplicationController
      include Authenticatable
      before_action :resolve_restaurant!
      before_action :authenticate_user!, only: %i[index show update]
      before_action :authorize_restaurant!, only: %i[index show update]
      before_action -> { require_permission!("orders:read") }, only: %i[index show]
      before_action -> { require_permission!("orders:update") }, only: :update

      def index
        orders = current_restaurant.orders.includes(order_items: [:product, :addons]).order(created_at: :desc)
        orders = orders.where(status: params[:status]) if params[:status].present?
        render json: orders.map { |order| serialized_order(order) }
      end

      def show
        render json: serialized_order(current_restaurant.orders.includes(order_items: [:product, :addons]).find(params[:id]))
      end

      def create
        permitted = order_params
        order = current_restaurant.orders.new(permitted.except(:items))
        order.order_items = Array(permitted[:items]).map do |item|
          product = current_restaurant.products.where(available: true).includes(:addons, :variants).find(item[:product_id])
          variants = product.variants.where(available: true)
          variant = item[:variant_id].present? ? variants.find_by(id: item[:variant_id]) : nil
          reject_invalid_addons!(order) if variants.any? && variant.nil?
          reject_invalid_addons!(order) if item[:variant_id].present? && variant.nil?
          addon_ids = Array(item[:addon_ids]).map(&:to_i)
          reject_invalid_addons!(order) if addon_ids.uniq.length != addon_ids.length
          addons = product.addons.where(available: true, id: addon_ids)
          reject_invalid_addons!(order) if addons.length != addon_ids.length

          base_price = variant ? variant.price : product.price
          order_item = OrderItem.new(product: product, quantity: item[:quantity], unit_price: base_price + addons.sum(:price), variant_name: variant&.name, variant_price: variant&.price, note: item[:note])
          addons.each { |addon| order_item.addons.build(name: addon.name, price: addon.price) }
          order_item
        end

        Order.transaction { order.save! }
        render json: serialized_order(order), status: :created
      end

      def track
        return render_tracking_limited unless OrderTrackingRateLimiter.allowed?(restaurant_slug: current_restaurant.slug, ip: request.remote_ip)

        lookup = tracking_lookup(params[:query])
        return render_tracking_invalid if lookup.nil?

        order = lookup[:type] == :id ? current_restaurant.orders.find_by(id: lookup[:value]) : tracked_order_for_phone(lookup[:value])
        return render_tracking_not_found unless order

        render json: {
          id: order.id,
          status: order.status,
          order_type: order.order_type,
          created_at: order.created_at
        }
      end

      def update
        order = current_restaurant.orders.find(params[:id])
        order.update(status: params.require(:order).permit(:status)[:status]) ? render(json: serialized_order(order)) : render_errors(order)
      end

      private

      def order_params
        params.require(:order).permit(:customer_name, :customer_phone, :order_type, :delivery_address, :table_number, :payment_method, items: [ :product_id, :quantity, :variant_id, :note, { addon_ids: [] } ])
      end

      def serialized_order(order)
        order.as_json(methods: :table_label, include: { order_items: { include: [:product, :addons] } })
      end

      def tracking_lookup(query)
        value = query.to_s.strip
        return nil if value.blank?

        match = value.match(/\A#(\d+)\z/)
        return { type: :id, value: match[1].to_i } if match

        digits = value.gsub(/\D/, "")
        phone = normalized_phone(digits)
        return { type: :phone, value: phone } if phone && (value.match?(/[^\d]/) || digits.length >= 10)
        return { type: :id, value: digits.to_i } if value.match?(/\A\d+\z/) && digits.to_i.positive?

        nil
      end

      def normalized_phone(digits)
        canonical = digits.length.in?(12..13) && digits.start_with?("55") ? digits.delete_prefix("55") : digits
        canonical if canonical.length.in?(10..11)
      end

      def tracked_order_for_phone(phone)
        phones = [phone, "55#{phone}"]
        scope = current_restaurant.orders.where("regexp_replace(customer_phone, '[^0-9]', '', 'g') IN (?)", phones)
        scope.where.not(status: %w[delivered cancelled]).order(created_at: :desc).first || scope.order(created_at: :desc).first
      end

      def render_tracking_invalid
        render json: { error: "tracking_query_invalid", messages: ["Informe um numero de pedido ou telefone valido."] }, status: :unprocessable_entity
      end

      def render_tracking_not_found
        render json: { error: "order_not_found", messages: ["Pedido nao encontrado."] }, status: :not_found
      end

      def render_tracking_limited
        render json: { error: "rate_limited", messages: ["Tente novamente em alguns instantes."] }, status: :too_many_requests
      end

      def reject_invalid_addons!(order)
        order.errors.add(:base, "adicionais inválidos para o produto")
        raise ActiveRecord::RecordInvalid, order
      end
    end
  end
end

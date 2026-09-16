module Api
  module Internal
    class RestaurantsController < BaseController
      before_action -> { require_platform_permission!("restaurants:read") }, only: %i[index show]
      before_action -> { require_platform_permission!("restaurants:create") }, only: :create
      before_action -> { require_platform_permission!("restaurants:update") }, only: :update
      before_action -> { require_platform_permission!("restaurants:lifecycle") }, only: %i[suspend reactivate]
      before_action :set_restaurant, only: %i[show update suspend reactivate]

      def index
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = [[params.fetch(:per_page, 20).to_i, 1].max, 100].min
        scope = Restaurant.left_joins(:users).distinct
        if params[:query].present?
          term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].to_s.downcase)}%"
          scope = scope.where("LOWER(restaurants.name) LIKE :term OR LOWER(restaurants.slug) LIKE :term OR LOWER(users.name) LIKE :term OR LOWER(users.email) LIKE :term", term: term)
        end
        scope = scope.where(status: params[:status]) if params[:status].present?
        total = scope.count
        restaurants = scope.order(created_at: :desc, id: :desc).offset((page - 1) * per_page).limit(per_page).to_a
        status_counts = Restaurant.group(:status).count
        render json: { restaurants: serialize_many(restaurants), meta: { page: page, per_page: per_page, total: total, status_counts: status_counts } }
      end

      def show
        render json: serialize_many([@restaurant]).first
      end

      def create
        result = RestaurantOnboarding.new(restaurant_attributes: restaurant_params, super_admin_attributes: super_admin_params).call!
        PlatformAudit.record(action: "restaurant.create", outcome: "success", actor: current_platform_user, target: result.restaurant, request: request)
        render json: { restaurant: serialize_many([result.restaurant]).first, super_admin: result.super_admin.as_json(except: :password_digest) }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        PlatformAudit.record(action: "restaurant.create", outcome: "failure", actor: current_platform_user, request: request, details: { errors: error.record.errors.full_messages })
        render_errors(error.record)
      end

      def update
        if @restaurant.update(restaurant_update_params)
          PlatformAudit.record(action: "restaurant.update", outcome: "success", actor: current_platform_user, target: @restaurant, request: request)
          render json: serialize_many([@restaurant]).first
        else
          PlatformAudit.record(action: "restaurant.update", outcome: "failure", actor: current_platform_user, target: @restaurant, request: request, details: { errors: @restaurant.errors.full_messages })
          render_errors(@restaurant)
        end
      end

      def suspend
        return lifecycle_conflict("Restaurant is already suspended") if @restaurant.suspended?
        reason = params.require(:reason).to_s.strip
        return render(json: { error: "validation_error", messages: ["Suspension reason is required"] }, status: :unprocessable_entity) if reason.blank?
        @restaurant.suspend!(reason: reason)
        PlatformAudit.record(action: "restaurant.suspend", outcome: "success", actor: current_platform_user, target: @restaurant, justification: reason, request: request)
        render json: serialize_many([@restaurant]).first
      end

      def reactivate
        return lifecycle_conflict("Restaurant is already active") unless @restaurant.suspended?
        @restaurant.reactivate!
        PlatformAudit.record(action: "restaurant.reactivate", outcome: "success", actor: current_platform_user, target: @restaurant, justification: params[:reason], request: request)
        render json: serialize_many([@restaurant]).first
      end

      private

      def set_restaurant = @restaurant = Restaurant.find(params[:id])
      def restaurant_params = params.require(:restaurant).permit(:name, :slug, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color, :font_family, menu_information: {})
      def restaurant_update_params = params.require(:restaurant).permit(:name, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :primary_color, :font_family, menu_information: {})
      def super_admin_params = params.require(:super_admin).permit(:name, :email, :password, :password_confirmation)

      def lifecycle_conflict(message)
        PlatformAudit.record(action: "restaurant.lifecycle", outcome: "failure", actor: current_platform_user, target: @restaurant, request: request, details: { reason: message })
        render json: { error: "lifecycle_conflict", messages: [message] }, status: :conflict
      end

      def serialize_many(restaurants)
        ids = restaurants.map(&:id)
        counts = {
          users: User.where(restaurant_id: ids).group(:restaurant_id).count,
          categories: Category.where(restaurant_id: ids).group(:restaurant_id).count,
          products: Product.where(restaurant_id: ids).group(:restaurant_id).count,
          orders: Order.where(restaurant_id: ids).group(:restaurant_id).count
        }
        owners = User.where(restaurant_id: ids, role: "superAdmin").index_by(&:restaurant_id)
        restaurants.map do |restaurant|
          restaurant.as_json.merge(
            "owner" => owners[restaurant.id]&.as_json(only: %i[id name email]),
            "counts" => counts.transform_values { |values| values.fetch(restaurant.id, 0) }
          )
        end
      end
    end
  end
end

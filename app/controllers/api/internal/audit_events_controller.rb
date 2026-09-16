module Api
  module Internal
    class AuditEventsController < BaseController
      before_action -> { require_platform_permission!("audits:read") }

      def index
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 100].min
        scope = PlatformAuditEvent.includes(:platform_user).order(created_at: :desc, id: :desc)
        scope = scope.where(platform_user_id: params[:actor_id]) if params[:actor_id].present?
        scope = scope.where(target_type: "Restaurant", target_id: params[:restaurant_id]) if params[:restaurant_id].present?
        scope = scope.where(action: params[:event_action]) if params[:event_action].present?
        scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
        scope = scope.where("created_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        scope = scope.where("created_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?
        total = scope.count
        events = scope.offset((page - 1) * per_page).limit(per_page)
        render json: { events: events.as_json(include: { platform_user: { only: %i[id name email] } }), meta: { page: page, per_page: per_page, total: total } }
      end
    end
  end
end

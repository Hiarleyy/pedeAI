class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "resource_not_found" }, status: :not_found
  end
  private
  def render_errors(record)
    render json: { error: "validation_error", messages: record.errors.full_messages }, status: :unprocessable_entity
  end
end

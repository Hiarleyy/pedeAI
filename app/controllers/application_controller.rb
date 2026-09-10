class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_invalid_request
  rescue_from ActionController::BadRequest, with: :render_bad_request
  rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record
  rescue_from ActiveRecord::RecordNotDestroyed, with: :render_invalid_record

  private

  def render_errors(record)
    render json: { error: "validation_error", messages: record.errors.full_messages }, status: :unprocessable_entity
  end

  def render_not_found
    render json: { error: "resource_not_found", messages: ["Resource not found"] }, status: :not_found
  end

  def render_invalid_request(error)
    render json: { error: "invalid_request", messages: [error.message] }, status: :bad_request
  end

  def render_bad_request(error)
    render json: { error: "validation_error", messages: [error.message] }, status: :unprocessable_entity
  end

  def render_invalid_record(error)
    render_errors(error.record)
  end
end

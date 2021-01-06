# frozen_string_literal: true

module ApiErrorResponses
  extend ActiveSupport::Concern

  private

  def respond_with_conflict(json_hash)
    render json: json_hash, status: :conflict
  end

  def error_during_processing(exception)
    render(json: { exception: exception.message },
           status: :unprocessable_entity) && return
  end

  def invalid_resource!(resource)
    @resource = resource
    render(json: { error: I18n.t(:invalid_resource, scope: "spree.api"),
                   errors: @resource.errors },
           status: :unprocessable_entity)
  end

  def invalid_api_key
    render(json: { error: I18n.t(:invalid_api_key, key: api_key, scope: "spree.api") },
           status: :unauthorized) && return
  end

  def unauthorized
    render(json: { error: I18n.t(:unauthorized, scope: "spree.api") },
           status: :unauthorized) && return
  end

  def not_found
    render(json: { error: I18n.t(:resource_not_found, scope: "spree.api") },
           status: :not_found) && return
  end
end

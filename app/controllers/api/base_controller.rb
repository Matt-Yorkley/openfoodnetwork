# Base controller for OFN's API
require_dependency 'spree/api/controller_setup'
require "spree/core/controller_helpers/ssl"

module Api
  class BaseController < ActionController::Metal
    include ApiErrorResponses
    include ActionController::StrongParameters
    include ActionController::RespondWith
    include Spree::Api::ControllerSetup
    include Spree::Core::ControllerHelpers::SSL
    include ::ActionController::Head
    include ::ActionController::ConditionalGet

    attr_accessor :current_api_user

    before_action :set_content_type
    before_action :authenticate_user

    layout false

    rescue_from Exception, with: :error_during_processing
    rescue_from CanCan::AccessDenied, with: :unauthorized
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    helper Spree::Api::ApiHelpers

    ssl_allowed

    # Include these because we inherit from ActionController::Metal
    #   rather than ActionController::Base and these are required for AMS
    include ActionController::Serialization
    include ActionController::UrlFor
    include Rails.application.routes.url_helpers

    use_renderers :json
    check_authorization

    private

    # Use logged in user (spree_current_user) for API authentication (current_api_user)
    def authenticate_user
      return if @current_api_user = spree_current_user

      if api_key.blank?
        # An anonymous user
        @current_api_user = Spree.user_class.new
        return
      end

      return if @current_api_user = Spree.user_class.find_by(spree_api_key: api_key.to_s)

      invalid_api_key
    end

    def set_content_type
      headers["Content-Type"] = "application/json"
    end

    def current_ability
      Spree::Ability.new(current_api_user)
    end

    def api_key
      request.headers["X-Spree-Token"] || params[:token]
    end
    helper_method :api_key
  end
end

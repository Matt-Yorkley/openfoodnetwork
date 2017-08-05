class UserConfirmationsController < DeviseController
  include Spree::Core::ControllerHelpers::Auth # Needed for access to current_ability, so we can authorize! actions

  # GET /resource/confirmation/new
  def new
    build_resource({})
  end

  # POST /resource/confirmation
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)

    if successfully_sent?(resource)
      respond_to do |format|
        format.html do
          set_flash_message(:success, :confirmation_sent) if is_navigational_format?
          respond_with_navigational(resource){ redirect_to login_path }
        end
        format.js do
          render json: resource
        end
      end
    else
      respond_to do |format|
        format.html do
          set_flash_message(:error, :confirmation_not_sent) if is_navigational_format?
          respond_with_navigational(resource){ redirect_to login_path }
        end
        format.js do
          render json: resource, status: :internal_server_error
        end
      end
    end
  end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty? && is_navigational_format?
      set_flash_message(:success, :confirmed)
    elsif is_navigational_format?
      set_flash_message(:error, :not_confirmed)
    end

    respond_with_navigational(resource){ redirect_to login_path }
  end

  protected

  # The path used after resending confirmation instructions.
  def after_resending_confirmation_instructions_path_for(resource_name)
    main_app.new_session_path(resource_name) if is_navigational_format?
  end

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    main_app.after_sign_in_path_for(resource)
  end
end

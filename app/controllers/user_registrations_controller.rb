class UserRegistrationsController < Spree::UserRegistrationsController
  before_filter :set_checkout_redirect, only: :create

  # POST /resource/sign_up
  def create
    @user = build_resource(params[:spree_user])
    if resource.save
      set_flash_message(:success, :signed_up)
      session[:spree_user_signup] = true
      associate_user

      respond_to do |format|
        format.html do
          redirect_to after_sign_in_path_for(@user)
        end
        format.js do
          render json: { email: @user.email }
        end
      end
    else
      clean_up_passwords(resource)
      respond_to do |format|
        format.html do
          render :new
        end
        format.js do
          render json: @user.errors, status: :unauthorized
        end
      end
    end
  end
end

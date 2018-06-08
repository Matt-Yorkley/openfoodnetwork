Spree::Admin::Orders::CustomerDetailsController.class_eval do
  before_filter :guest_checkout_status, only: :update

  # Inherit CanCan permissions for the current order
  def model_class
    load_order unless @order
    @order
  end

  private

  def guest_checkout_status
    registered = Spree.user_class.exists?(email: params[:order][:email])

    params[:order][:guest_checkout] = !registered
  end
end

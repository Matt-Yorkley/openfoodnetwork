require 'open_food_network/permissions'

Spree::Api::ProductsController.class_eval do
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 15

  def managed
    authorize! :admin, Spree::Product
    authorize! :read, Spree::Product

    @products = product_scope.ransack(params[:q]).result.managed_by(current_api_user).page(params[:page]).per(params[:per_page])
    respond_with(@products, default_template: :index)
  end

  # TODO: This should be named 'managed'. Is the action above used? Maybe we should remove it.
  def bulk_products
    product_query = OpenFoodNetwork::Permissions.new(current_api_user).
      editable_products.merge(product_scope)

    if params[:import_date].present?
      product_query = product_query.joins(:variants).merge(import_date_scope).group_by_products_id
    end

    @products = product_query.order('created_at DESC').
      ransack(params[:q]).result.
      page(params[:page] || DEFAULT_PAGE).per(params[:per_page] || DEFAULT_PER_PAGE)

    render_paged_products @products
  end

  def overridable
    producers = OpenFoodNetwork::Permissions.new(current_api_user).
      variant_override_producers.by_name

    @products = paged_products_for_producers producers

    render_paged_products @products
  end

  def soft_delete
    authorize! :delete, Spree::Product
    @product = find_product(params[:product_id])
    authorize! :delete, @product
    @product.destroy
    respond_with(@product, status: 204)
  end

  # POST /api/products/:product_id/clone
  #
  def clone
    authorize! :create, Spree::Product
    original_product = find_product(params[:product_id])
    authorize! :update, original_product

    @product = original_product.duplicate

    respond_with(@product, status: 201, default_template: :show)
  end

  private

  # Copied and modified from Spree::Api::BaseController to allow
  # enterprise users to access inactive products
  def product_scope
    if current_api_user.has_spree_role?("admin") || current_api_user.enterprises.present? # This line modified
      scope = Spree::Product
      if params[:show_deleted]
        scope = scope.with_deleted
      end
    else
      scope = Spree::Product.active
    end

    scope.includes(:master)
  end

  def import_date_scope
    import_date = params[:import_date].to_datetime
    Spree::Variant.where(import_date: import_date..import_date + 24.hours)
  end

  def paged_products_for_producers(producers)
    Spree::Product.scoped.
      merge(product_scope).
      where(supplier_id: producers).
      by_producer.by_name.
      ransack(params[:q]).result.
      page(params[:page]).per(params[:per_page])
  end

  def render_paged_products(products)
    serializer = ActiveModel::ArraySerializer.new(
      products,
      each_serializer: Api::Admin::ProductSerializer
    )

    render text: {
      products: serializer,
      pagination: pagination_data(products)
    }.to_json
  end

  def pagination_data(results)
    {
      results: results.total_count,
      pages: results.num_pages,
      page: (params[:page].to_i || DEFAULT_PAGE).to_i,
      per_page: (params[:per_page].to_i || DEFAULT_PER_PAGE).to_i
    }
  end
end

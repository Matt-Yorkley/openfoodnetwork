# frozen_string_literal: true

module OrderManagement
  module Reports
    module Packing
      class Customer < Report
        def self.report_subtypes
          ['customer', 'supplier']
        end

        def collection
          Spree::LineItem.includes(*line_item_includes).where(order_id: order_ids).uniq
        end

        def report_row(object)
          {
            order_id: object.order_id,
            hub: orders[object.order_id].distributor.name,
            customer_code: orders[object.order_id].customer.andand.code,
            first_name: orders[object.order_id].bill_address.firstname,
            last_name: orders[object.order_id].bill_address.lastname,
            supplier: object.product.supplier.name,
            product: object.product.name,
            variant: object.full_name,
            quantity: object.quantity,
            is_temperature_controlled: object.product.shipping_category.andand.temperature_controlled ? "Yes" : "No"
          }
        end

        def ordering
          [:hub, :order_id, :last_name, :supplier, :product, :variant]
        end

        def summary_group
          :order_id
        end

        def summary_row
          { title: 'TOTAL', sum: [:quantity] }
        end

        def hide_columns
          [:order_id]
        end

        def mask_data
          {
              columns: [:customer_code, :first_name, :last_name],
              replacement: "< Hidden >",
              rule: proc{ |line_item| !can_view_customer_data?(line_item) }
          }
        end

        private

        def permissions
          Permissions::Order.new(current_user, ransack_params)
        end

        def orders
          @orders ||= permissions.visible_orders.
              complete.not_state(:canceled).
              includes(:bill_address, :distributor, :customer).
              ransack(ransack_params).result.index_by(&:id)
        end

        def order_ids
          orders.keys
        end

        def line_item_includes
          [{
               option_values: :option_type,
               variant: { product: [:supplier, :shipping_category] }
           }]
        end

        def can_view_customer_data?(line_item)
          managed_enterprise_ids.include? orders[line_item.order_id].distributor_id
        end

        def managed_enterprise_ids
          @managed_enterprise_ids ||= Enterprise.managed_by(current_user).pluck(:id)
        end
      end
    end
  end
end

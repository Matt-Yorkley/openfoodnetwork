# frozen_string_literal: true

module OrderManagement
  module Reports
    module Packing
      class Customer < Base
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
            is_temperature_controlled: temp_controlled_value(object)
          }
        end

        def ordering
          [:hub, :order_id, :last_name, :supplier, :product, :variant]
        end

        def summary_group
          :order_id
        end
      end
    end
  end
end

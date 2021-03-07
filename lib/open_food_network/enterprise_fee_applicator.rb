module OpenFoodNetwork
  class EnterpriseFeeApplicator < Struct.new(:enterprise_fee, :variant, :role)
    def create_line_item_adjustment(line_item)
      create_adjustment(line_item_adjustment_label, line_item, line_item)
    end

    def create_order_adjustment(order)
      create_adjustment(order_adjustment_label, order, order)
    end

    private

    def create_adjustment(label, target, calculable)
      adjustment = enterprise_fee.create_adjustment(
        label, target, calculable, true, "closed", tax_category(target)
      )

      AdjustmentMetadata.create! adjustment: adjustment, enterprise: enterprise_fee.enterprise, fee_name: enterprise_fee.name, fee_type: enterprise_fee.fee_type, enterprise_role: role
    end

    def line_item_adjustment_label
      "#{variant.product.name} - #{base_adjustment_label}"
    end

    def order_adjustment_label
      "#{I18n.t(:enterprise_fee_whole_order)} - #{base_adjustment_label}"
    end

    def base_adjustment_label
      I18n.t(:enterprise_fee_by, type: enterprise_fee.fee_type, role: role, enterprise_name: enterprise_fee.enterprise.name)
    end

    def tax_category(target)
      if target.is_a?(Spree::LineItem) && enterprise_fee.inherits_tax_category?
        target.product.tax_category
      else
        enterprise_fee.tax_category
      end
    end
  end
end

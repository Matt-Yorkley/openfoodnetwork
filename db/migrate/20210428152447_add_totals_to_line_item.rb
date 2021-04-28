class AddTotalsToLineItem < ActiveRecord::Migration[5.0]
  def up
    add_column :spree_line_items, :included_tax_total, :decimal,
               precision: 10, scale: 2, null: false, default: 0.0
    add_column :spree_line_items, :additional_tax_total, :decimal,
               precision: 10, scale: 2, null: false, default: 0.0
    add_column :spree_line_items, :adjustment_total, :decimal,
               precision: 10, scale: 2, null: false, default: 0.0

    populate_adjustment_totals
  end

  def down
    remove_column :spree_line_items, :included_tax_total
    remove_column :spree_line_items, :additional_tax_total
    remove_column :spree_line_items, :adjustment_total
  end

  def populate_adjustment_totals
    Spree::LineItem.find_each do |line_item|
      included_tax_total = all_adjustments.tax.inclusive.sum(:amount)
      additional_tax_total = all_adjustments.tax.additional.sum(:amount)
      fees_total = adjustments.enterprise_fee.sum(:amount)

      line_item.update_columns(
        included_tax_total: included_tax_total,
        additional_tax_total: additional_tax_total,
        adjustment_total: fees_total + additional_tax_total
      )
    end
  end
end

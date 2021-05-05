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
    adjustment_totals_sql = <<-SQL
      UPDATE spree_line_items
      SET adjustment_total = totals.adjustment_total,
        additional_tax_total = totals.additional_tax_total,
        included_tax_total = totals.included_tax_total
      FROM (
        SELECT spree_line_items.id AS line_item_id,
          COALESCE(additional_tax_adjustments.sum, 0) AS additional_tax_total,
          COALESCE(included_tax_adjustments.sum, 0) AS included_tax_total,
          (COALESCE(fee_adjustments.sum, 0) + COALESCE(additional_tax_adjustments.sum, 0)) AS adjustment_total
        FROM spree_line_items
        LEFT JOIN (
          SELECT adjustable_id, SUM(amount) AS sum
          FROM spree_adjustments
          WHERE spree_adjustments.adjustable_type = 'Spree::LineItem'
            AND spree_adjustments.originator_type = 'EnterpriseFee'
          GROUP BY adjustable_id
        ) fee_adjustments ON spree_line_items.id = fee_adjustments.adjustable_id
        LEFT JOIN (
          SELECT adjustable_id, SUM(amount) AS sum
          FROM spree_adjustments
          WHERE spree_adjustments.adjustable_type = 'Spree::LineItem'
            AND spree_adjustments.originator_type = 'Spree::TaxRate'
            AND spree_adjustments.included IS FALSE
          GROUP BY adjustable_id
        ) additional_tax_adjustments ON spree_line_items.id = additional_tax_adjustments.adjustable_id
        LEFT JOIN (
          SELECT adjustable_id, SUM(amount) AS sum
          FROM spree_adjustments
          WHERE spree_adjustments.adjustable_type = 'Spree::LineItem'
            AND spree_adjustments.originator_type = 'Spree::TaxRate'
            AND spree_adjustments.included IS TRUE
          GROUP BY adjustable_id
        ) included_tax_adjustments ON spree_line_items.id = included_tax_adjustments.adjustable_id
      ) totals
      WHERE totals.line_item_id = spree_line_items.id
    SQL

    ActiveRecord::Base.connection.execute(adjustment_totals_sql)
  end
end

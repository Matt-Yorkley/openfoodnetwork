class AddTotalsToLineItem < ActiveRecord::Migration[5.0]
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
  class Spree::LineItem < ApplicationRecord
    has_many :adjustments, as: :adjustable, dependent: :destroy

    def all_adjustments
      Spree::Adjustment.where(id: adjustment_ids).or(
        Spree::Adjustment.where(
          adjustable_type: 'Spree::Adjustment', adjustable_id: adjustment_ids
        )
      )
    end
  end
  class Spree::Adjustment < ApplicationRecord
    belongs_to :originator, -> { with_deleted }, polymorphic: true
    belongs_to :adjustable, polymorphic: true
    belongs_to :order, class_name: "Spree::Order"
    belongs_to :tax_category, class_name: 'Spree::TaxCategory'
    has_many :adjustments, as: :adjustable, dependent: :destroy

    scope :tax, -> { where(originator_type: 'Spree::TaxRate') }
    scope :inclusive, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
    scope :enterprise_fee, -> { where(originator_type: 'EnterpriseFee') }
  end

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
    # Populates the new `adjustment_total` field in the spree_shipments table. Sets the value
    # to the shipment's (shipping fee) adjustment amount.

    adjustment_totals_sql = <<-SQL
      UPDATE spree_line_items
      SET adjustment_total = totals.adjustment_total,
        additional_tax_total = totals.additional_tax_total,
        included_tax_total = totals.included_tax_total,
      FROM (
        SELECT spree_line_items.id AS line_item_id,
          COALESCE(fee_adjustments.sum, 0) AS adjustment_total,
          COALESCE(additional_tax_adjustments.sum, 0) AS additional_tax_total,
          COALESCE(included_tax_adjustments.sum, 0) AS included_tax_total
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

  def populate_adjustment_totals2
    Spree::LineItem.find_each do |line_item|
      included_tax_total = line_item.all_adjustments.tax.inclusive.sum(:amount)
      additional_tax_total = line_item.all_adjustments.tax.additional.sum(:amount)
      fees_total = line_item.adjustments.enterprise_fee.sum(:amount)

      line_item.update_columns(
        included_tax_total: included_tax_total,
        additional_tax_total: additional_tax_total,
        adjustment_total: fees_total + additional_tax_total
      )
    end
  end
end

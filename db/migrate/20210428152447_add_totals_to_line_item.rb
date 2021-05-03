class AddTotalsToLineItem < ActiveRecord::Migration[5.0]
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

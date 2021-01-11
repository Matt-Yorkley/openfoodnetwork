# frozen_string_literal: true

require 'spree/localized_number'
require 'concerns/adjustment_scopes'

# Adjustments represent a change to the +item_total+ of an Order. Each adjustment
# has an +amount+ that can be either positive or negative.
#
# Adjustments can be open/closed/finalized
#
# Once an adjustment is finalized, it cannot be changed, but an adjustment can
# toggle between open/closed as needed
#
# Boolean attributes:
#
# +mandatory+
#
# If this flag is set to true then it means the the charge is required and will not
# be removed from the order, even if the amount is zero. In other words a record
# will be created even if the amount is zero. This is useful for representing things
# such as shipping and tax charges where you may want to make it explicitly clear
# that no charge was made for such things.
#
# +eligible?+
#
# This boolean attributes stores whether this adjustment is currently eligible
# for its order. Only eligible adjustments count towards the order's adjustment
# total. This allows an adjustment to be preserved if it becomes ineligible so
# it might be reinstated.
module Spree
  class Adjustment < ActiveRecord::Base
    extend Spree::LocalizedNumber

    # Deletion of metadata is handled in the database.
    # So we don't need the option `dependent: :destroy` as long as
    # AdjustmentMetadata has no destroy logic itself.
    has_one :metadata, class_name: 'AdjustmentMetadata'

    belongs_to :adjustable, polymorphic: true
    belongs_to :source, polymorphic: true
    belongs_to :order

    # The diffs with Spree 2.2 don't have this association listed at all and it seems to break adjustments.
    # This needs to be removed / re-adjusted.
    # See https://github.com/openfoodfoundation/openfoodnetwork/commit/2d2792225a607a06dbd06aab694030a5cfa04d95#diff-7e5462a3bd9c8321c204cfba2377a185494da02b4e6dbef00763416a9957398aR7
    belongs_to :tax_rate, -> { where spree_adjustments: { source_type: 'Spree::TaxRate' } },
               foreign_key: 'source_id'

    validates :label, presence: true
    validates :amount, numericality: true

    after_create :update_adjustable_adjustment_total

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end

      event :finalize do
        transition from: [:open, :closed], to: :finalized
      end
    end

    scope :open, -> { where(state: 'open') }
    scope :tax, -> { where(source_type: 'Spree::TaxRate') }
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :optional, -> { where(mandatory: false) }
    scope :charge, -> { where('amount >= 0') }
    scope :credit, -> { where('amount < 0') }
    scope :return_authorization, -> { where(source_type: "Spree::ReturnAuthorization") }

    scope :enterprise_fee, -> { where(originator_type: 'EnterpriseFee') }
    scope :admin,          -> { where(source_type: nil, originator_type: nil) }
    scope :included_tax,   -> {
      where(originator_type: 'Spree::TaxRate', adjustable_type: 'Spree::LineItem')
    }

    scope :with_tax,       -> { where('spree_adjustments.included_tax <> 0') }
    scope :without_tax,    -> { where('spree_adjustments.included_tax = 0') }
    scope :payment_fee,    -> { where(AdjustmentScopes::PAYMENT_FEE_SCOPE) }
    scope :shipping,       -> { where(AdjustmentScopes::SHIPPING_SCOPE) }
    scope :eligible,       -> { where(AdjustmentScopes::ELIGIBLE_SCOPE) }

    localize_number :amount

    # Recalculate amount given a target e.g. Order, Shipment, LineItem
    #
    # Passing a target here would always be recommended as it would avoid
    # hitting the database again and would ensure you're compute values over
    # the specific object amount passed here
    def update!(target = nil)
      return amount if immutable?

      amount = source.compute_amount(target || adjustable)
      self.update_column(:amount, amount)
      amount
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, currency: currency)
    end

    def immutable?
      state != "open"
    end

    def set_included_tax!(rate)
      tax = amount - (amount / (1 + rate))
      set_absolute_included_tax! tax
    end

    def set_absolute_included_tax!(tax)
      # This rubocop issue can now fixed by renaming Adjustment#update! to something else,
      #   then AR's update! can be used instead of update_attributes!
      # rubocop:disable Rails/ActiveRecordAliases
      update_attributes! included_tax: tax.round(2)
      # rubocop:enable Rails/ActiveRecordAliases
    end

    def display_included_tax
      Spree::Money.new(included_tax, currency: currency)
    end

    def has_tax?
      included_tax.positive?
    end

    def self.without_callbacks
      skip_callback :save, :after, :update_adjustable
      skip_callback :destroy, :after, :update_adjustable

      result = yield
    ensure
      set_callback :save, :after, :update_adjustable
      set_callback :destroy, :after, :update_adjustable

      result
    end

    private

    def update_adjustable_adjustment_total
      # Cause adjustable's total to be recalculated
      Spree::ItemAdjustments.new(adjustable).update if adjustable
    end
  end
end

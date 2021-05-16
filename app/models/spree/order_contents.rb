# frozen_string_literal: true

module Spree
  class OrderContents
    attr_accessor :order

    def initialize(order)
      @order = order
    end

    # Get current line item for variant if exists
    # Add variant qty to line_item
    def add(variant, quantity = 1, shipment = nil)
      line_item = add_to_line_item(variant, quantity, shipment)
      update_shipment(shipment)
      update_order
      line_item
    end

    # Get current line item for variant
    # Remove variant qty from line_item
    def remove(variant, quantity = nil, shipment = nil)
      line_item = remove_from_line_item(variant, quantity, shipment)
      update_shipment(shipment)
      order.update_order_fees! if order.completed?
      update_order
      line_item
    end

    def update_or_create(variant, attributes)
      line_item = find_line_item_by_variant(variant)

      if line_item
        line_item.update(attributes)
      else
        line_item = Spree::LineItem.new(attributes)
        line_item.variant = variant
        line_item.price = variant.price
        order.line_items << line_item
      end

      order.reload
      line_item
    end

    def update_cart(params)
      if order.update_attributes(params)
        discard_empty_line_items
        order.ensure_updated_shipments
        update_order
        true
      else
        false
      end
    end

    def update_item(line_item, params)
      if line_item.update_attributes(params)
        order.update_line_item_fees! line_item
        order.update_order_fees! if order.completed?
        discard_empty_line_items
        order.ensure_updated_shipments
        update_order
        true
      else
        false
      end
    end

    private

    def discard_empty_line_items
      order.line_items = order.line_items.select {|li| li.quantity.positive? }
    end

    def update_shipment(shipment)
      # This is the bit that needs careful tests...
      # Is shipment.update_amounts actually working as intended? Needs a test.
      # Should we even be calling this in all these cases in OrderContents? Needs investigation, and tests.
      # If shipment.update_amounts is pointless, maybe just drop it and simplify this...?
      #
      # AHA! This is used in #add and #remove, and shipment is nil unless passed explicitly. And that is
      # only done is Api::ShipmentsController... which passes explicit shipments.
      # Okay, so in *that* case; are we actually updating the shipment correctly? Seems like no. In
      # Api::ShipmentsController#create we refresh rates and re-save the shipment after this update is done...
      # But isn't that in the wrong order...? We probably want to refresh rates if a shipment has been passed,
      # and then update the order afterwards to ensure everything is correct...?
      shipment.present? ? shipment.update_amounts : order.ensure_updated_shipments
    end

    def add_to_line_item(variant, quantity, shipment = nil)
      line_item = find_line_item_by_variant(variant)

      if line_item
        line_item.target_shipment = shipment
        line_item.quantity += quantity.to_i
      else
        line_item = order.line_items.new(quantity: quantity, variant: variant)
        line_item.target_shipment = shipment
        line_item.price = variant.price
      end

      line_item.save
      line_item
    end

    def remove_from_line_item(variant, quantity, shipment = nil)
      line_item = find_line_item_by_variant(variant, true)

      quantity.present? ? line_item.quantity += -quantity : line_item.quantity = 0
      line_item.target_shipment = shipment

      if line_item.quantity == 0
        line_item.destroy
      else
        line_item.save!
      end

      line_item
    end

    def find_line_item_by_variant(variant, raise_error = false)
      line_item = order.find_line_item_by_variant(variant)

      if !line_item.present? && raise_error
        raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
      end

      line_item
    end

    def update_order
      order.update!
      order.reload
    end
  end
end

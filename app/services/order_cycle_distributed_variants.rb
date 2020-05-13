class OrderCycleDistributedVariants
  def initialize(order_cycle, distributor)
    @order_cycle = order_cycle
    @distributor = distributor
  end

  def distributes_order_variants?(order)
    unavailable_order_variants(order).empty?
  end

  def unavailable_order_variants(order)
    order.line_item_variants - available_variants
  end

  def available_variants
    # This method is skipped if @order_cycle is nil, and it often is in tests...
    return [] unless @order_cycle

    # This method will not return soft-deleted variants, or variants recently removed from the OC,
    # which can trigger the fatal error when loading the shop page...

    @order_cycle.variants_distributed_by(@distributor)
  end
end

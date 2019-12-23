require 'open_food_network/scope_variant_to_hub'

class OrderCycle < ActiveRecord::Base
  belongs_to :coordinator, class_name: 'Enterprise'

  has_many :coordinator_fee_refs, class_name: 'CoordinatorFee'
  has_many :coordinator_fees, through: :coordinator_fee_refs, source: :enterprise_fee

  has_many :exchanges, dependent: :destroy

  # These scope names are prepended with "cached_" because there are existing accessor methods
  # :incoming_exchanges and :outgoing_exchanges.
  has_many :cached_incoming_exchanges, conditions: { incoming: true }, class_name: "Exchange"
  has_many :cached_outgoing_exchanges, conditions: { incoming: false }, class_name: "Exchange"

  has_many :suppliers, source: :sender, through: :cached_incoming_exchanges, uniq: true
  has_many :distributors, source: :receiver, through: :cached_outgoing_exchanges, uniq: true

  has_and_belongs_to_many :schedules, join_table: 'order_cycle_schedules'

  attr_accessor :incoming_exchanges, :outgoing_exchanges

  validates :name, :coordinator_id, presence: true
  validate :orders_close_at_after_orders_open_at?

  preference :product_selection_from_coordinator_inventory_only, :boolean, default: false

  scope :active, lambda {
    where('order_cycles.orders_open_at <= ? AND order_cycles.orders_close_at >= ?',
          Time.zone.now,
          Time.zone.now)
  }
  scope :active_or_complete, lambda { where('order_cycles.orders_open_at <= ?', Time.zone.now) }
  scope :inactive, lambda {
    where('order_cycles.orders_open_at > ? OR order_cycles.orders_close_at < ?',
          Time.zone.now,
          Time.zone.now)
  }
  scope :upcoming, lambda { where('order_cycles.orders_open_at > ?', Time.zone.now) }
  scope :not_closed, lambda {
    where('order_cycles.orders_close_at > ? OR order_cycles.orders_close_at IS NULL', Time.zone.now)
  }
  scope :closed, lambda {
    where('order_cycles.orders_close_at < ?',
          Time.zone.now).order("order_cycles.orders_close_at DESC")
  }
  scope :undated, -> { where('order_cycles.orders_open_at IS NULL OR orders_close_at IS NULL') }
  scope :dated, -> { where('orders_open_at IS NOT NULL AND orders_close_at IS NOT NULL') }

  scope :soonest_closing,      lambda { active.order('order_cycles.orders_close_at ASC') }
  # This scope returns all the closed orders
  scope :most_recently_closed, lambda { closed.order('order_cycles.orders_close_at DESC') }

  scope :soonest_opening,      lambda { upcoming.order('order_cycles.orders_open_at ASC') }

  scope :by_name, -> { order('name') }

  scope :with_distributor, lambda { |distributor|
    joins(:exchanges).merge(Exchange.outgoing).merge(Exchange.to_enterprise(distributor))
  }

  scope :managed_by, lambda { |user|
    if user.has_spree_role?('admin')
      scoped
    else
      where(coordinator_id: user.enterprises.select('enterprises.id').map(&:id))
    end
  }

  # Return order cycles that user coordinates, sends to or receives from
  scope :accessible_by, lambda { |user|
    if user.has_spree_role?('admin')
      scoped
    else
      with_exchanging_enterprises_outer.
        where('order_cycles.coordinator_id IN (?) OR enterprises.id IN (?)',
              user.enterprises.map(&:id),
              user.enterprises.map(&:id)).
        select('DISTINCT order_cycles.*')
    end
  }

  scope :with_exchanging_enterprises_outer, lambda {
    joins("LEFT OUTER JOIN exchanges ON (exchanges.order_cycle_id = order_cycles.id)").
      joins("LEFT OUTER JOIN enterprises
          ON (enterprises.id = exchanges.sender_id OR enterprises.id = exchanges.receiver_id)")
  }

  scope :involving_managed_distributors_of, lambda { |user|
    enterprises = Enterprise.managed_by(user)

    # Order cycles where I managed an enterprise at either end of an outgoing exchange
    # ie. coordinator or distributor
    joins(:exchanges).merge(Exchange.outgoing).
      where('exchanges.receiver_id IN (?) OR exchanges.sender_id IN (?)',
            enterprises.pluck(:id),
            enterprises.pluck(:id)).
      select('DISTINCT order_cycles.*')
  }

  scope :involving_managed_producers_of, lambda { |user|
    enterprises = Enterprise.managed_by(user)

    # Order cycles where I managed an enterprise at either end of an incoming exchange
    # ie. coordinator or producer
    joins(:exchanges).merge(Exchange.incoming).
      where('exchanges.receiver_id IN (?) OR exchanges.sender_id IN (?)',
            enterprises.pluck(:id),
            enterprises.pluck(:id)).
      select('DISTINCT order_cycles.*')
  }

  def self.first_opening_for(distributor)
    with_distributor(distributor).soonest_opening.first
  end

  def self.first_closing_for(distributor)
    with_distributor(distributor).soonest_closing.first
  end

  def self.most_recently_closed_for(distributor)
    with_distributor(distributor).most_recently_closed.first
  end

  # Find the earliest closing times for each distributor in an active order cycle, and return
  # them in the format {distributor_id => closing_time, ...}
  def self.earliest_closing_times
    Hash[
      Exchange.
        outgoing.
        joins(:order_cycle).
        merge(OrderCycle.active).
        group('exchanges.receiver_id').
        select("exchanges.receiver_id AS receiver_id,
                MIN(order_cycles.orders_close_at) AS earliest_close_at").
        map { |ex| [ex.receiver_id, ex.earliest_close_at.to_time] }
    ]
  end

  def clone!
    oc = dup
    oc.name = I18n.t("models.order_cycle.cloned_order_cycle_name", order_cycle: oc.name)
    oc.orders_open_at = oc.orders_close_at = nil
    oc.coordinator_fee_ids = coordinator_fee_ids
    # rubocop:disable Metrics/LineLength
    oc.preferred_product_selection_from_coordinator_inventory_only = preferred_product_selection_from_coordinator_inventory_only
    # rubocop:enable Metrics/LineLength
    oc.save!
    exchanges.each { |e| e.clone!(oc) }
    oc.reload
  end

  def variants
    Spree::Variant.
      joins(:exchanges).
      merge(Exchange.in_order_cycle(self)).
      select('DISTINCT spree_variants.*').
      to_a # http://stackoverflow.com/q/15110166
  end

  def supplied_variants
    exchanges.incoming.map(&:variants).flatten.uniq.reject(&:deleted?)
  end

  def distributed_variants
    exchanges.outgoing.map(&:variants).flatten.uniq.reject(&:deleted?)
  end

  def variants_distributed_by(distributor)
    return Spree::Variant.where("1=0") if distributor.blank?

    Spree::Variant.
      joins(:exchanges).
      merge(distributor.inventory_variants).
      merge(Exchange.in_order_cycle(self)).
      merge(Exchange.outgoing).
      merge(Exchange.to_enterprise(distributor))
  end

  def products_distributed_by(distributor)
    variants_distributed_by(distributor).map(&:product).uniq
  end

  def products
    variants.map(&:product).uniq
  end

  def has_distributor?(distributor)
    distributors.include? distributor
  end

  def has_variant?(variant)
    variants.include? variant
  end

  def dated?
    !undated?
  end

  def undated?
    orders_open_at.nil? || orders_close_at.nil?
  end

  def upcoming?
    orders_open_at && Time.zone.now < orders_open_at
  end

  def open?
    orders_open_at && orders_close_at &&
      Time.zone.now > orders_open_at && Time.zone.now < orders_close_at
  end

  def closed?
    orders_close_at && Time.zone.now > orders_close_at
  end

  def exchange_for_distributor(distributor)
    exchanges.outgoing.to_enterprises([distributor]).first
  end

  def exchange_for_supplier(supplier)
    exchanges.incoming.from_enterprises([supplier]).first
  end

  def receival_instructions_for(supplier)
    exchange_for_supplier(supplier).andand.receival_instructions
  end

  def pickup_time_for(distributor)
    exchange_for_distributor(distributor).andand.pickup_time || distributor.next_collection_at
  end

  def pickup_instructions_for(distributor)
    exchange_for_distributor(distributor).andand.pickup_instructions
  end

  def exchanges_carrying(variant, distributor)
    exchanges.supplying_to(distributor).with_variant(variant)
  end

  def exchanges_supplying(order)
    exchanges.supplying_to(order.distributor).with_any_variant(order.variants.map(&:id))
  end

  def coordinated_by?(user)
    coordinator.users.include? user
  end

  def items_bought_by_user(user, distributor)
    # The Spree::Order.complete scope only checks for completed_at date
    #   it does not ensure state is "complete"
    orders = Spree::Order.complete.where(state: "complete",
                                         user_id: user,
                                         distributor_id: distributor,
                                         order_cycle_id: self)
    scoper = OpenFoodNetwork::ScopeVariantToHub.new(distributor)
    items = Spree::LineItem.joins(:order).merge(orders)
    items.each { |li| scoper.scope(li.variant) }
  end

  private

  def orders_close_at_after_orders_open_at?
    return if orders_open_at.blank? || orders_close_at.blank?
    return if orders_close_at > orders_open_at

    errors.add(:orders_close_at, :after_orders_open_at)
  end
end

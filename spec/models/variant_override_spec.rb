require 'spec_helper'

describe VariantOverride do
  let(:variant) { create(:variant) }
  let(:hub)     { create(:distributor_enterprise) }

  describe "scopes" do
    let(:hub1) { create(:distributor_enterprise) }
    let(:hub2) { create(:distributor_enterprise) }
    let!(:vo1) { create(:variant_override, hub: hub1, variant: variant, import_date: Time.zone.now.yesterday) }
    let!(:vo2) { create(:variant_override, hub: hub2, variant: variant, import_date: Time.zone.now) }
    let!(:vo3) { create(:variant_override, hub: hub1, variant: variant, permission_revoked_at: Time.now) }

    it "ignores variant_overrides with revoked_permissions by default" do
      expect(VariantOverride.all).to_not include vo3
      expect(VariantOverride.unscoped).to include vo3
    end

    it "finds variant overrides for a set of hubs" do
      VariantOverride.for_hubs([hub1, hub2]).should match_array [vo1, vo2]
    end

    it "fetches import dates for hubs in descending order" do
      import_dates = VariantOverride.distinct_import_dates.pluck :import_date

      expect(import_dates[0].to_i).to eq(vo2.import_date.to_i)
      expect(import_dates[1].to_i).to eq(vo1.import_date.to_i)
    end

    describe "fetching variant overrides indexed by variant" do
      it "gets indexed variant overrides for one hub" do
        VariantOverride.indexed(hub1).should == {variant => vo1}
        VariantOverride.indexed(hub2).should == {variant => vo2}
      end
    end
  end


  describe "callbacks" do
    let!(:vo) { create(:variant_override, hub: hub, variant: variant) }

    it "refreshes the products cache on save" do
      expect(OpenFoodNetwork::ProductsCache).to receive(:variant_override_changed).with(vo)
      vo.price = 123.45
      vo.save
    end

    it "refreshes the products cache on destroy" do
      expect(OpenFoodNetwork::ProductsCache).to receive(:variant_override_destroyed).with(vo)
      vo.destroy
    end
  end


  describe "looking up prices" do
    it "returns the numeric price when present" do
      VariantOverride.create!(variant: variant, hub: hub, price: 12.34)
      VariantOverride.price_for(hub, variant).should == 12.34
    end

    it "returns nil otherwise" do
      VariantOverride.price_for(hub, variant).should be_nil
    end
  end

  describe "looking up count on hand" do
    it "returns the numeric stock level when present" do
      VariantOverride.create!(variant: variant, hub: hub, count_on_hand: 12)
      VariantOverride.count_on_hand_for(hub, variant).should == 12
    end

    it "returns nil otherwise" do
      VariantOverride.count_on_hand_for(hub, variant).should be_nil
    end
  end

  describe "checking if stock levels have been overriden" do
    it "returns true when stock level has been overridden" do
      create(:variant_override, variant: variant, hub: hub, count_on_hand: 12)
      VariantOverride.stock_overridden?(hub, variant).should be true
    end

    it "returns false when the override has no stock level" do
      create(:variant_override, variant: variant, hub: hub, count_on_hand: nil)
      VariantOverride.stock_overridden?(hub, variant).should be false
    end

    it "returns false when there is no override for the hub/variant" do
      VariantOverride.stock_overridden?(hub, variant).should be false
    end
  end

  describe "decrementing stock" do
    it "decrements stock" do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12)
      VariantOverride.decrement_stock! hub, variant, 2
      vo.reload.count_on_hand.should == 10
    end

    it "silently logs an error if the variant override does not exist" do
      Bugsnag.should_receive(:notify)
      VariantOverride.decrement_stock! hub, variant, 2
    end
  end

  describe "incrementing stock" do
    let!(:vo) { create(:variant_override, variant: variant, hub: hub, count_on_hand: 8) }

    context "when the vo overrides stock" do
      it "increments stock" do
        vo.increment_stock! 2
        vo.reload.count_on_hand.should == 10
      end
    end

    context "when the vo doesn't override stock" do
      before { vo.update_attributes(count_on_hand: nil) }

      it "silently logs an error" do
        Bugsnag.should_receive(:notify)
        vo.increment_stock! 2
      end
    end
  end

  describe "checking default stock value is present" do
    it "returns true when a default stock level has been set"  do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12, default_stock: 20)
      vo.default_stock?.should be true
    end

    it "returns false when the override has no default stock level" do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12, default_stock:nil)
      vo.default_stock?.should be false
    end
  end

  describe "resetting stock levels" do
    it "resets the on hand level to the value in the default_stock field" do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12, default_stock: 20, resettable: true)
      vo.reset_stock!
      vo.reload.count_on_hand.should == 20
    end
    it "silently logs an error if the variant override doesn't have a default stock level" do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12, default_stock:nil, resettable: true)
      Bugsnag.should_receive(:notify)
      vo.reset_stock!
      vo.reload.count_on_hand.should == 12
    end
    it "doesn't reset the level if the behaviour is disabled" do
      vo = create(:variant_override, variant: variant, hub: hub, count_on_hand: 12, default_stock: 10, resettable: false)
      vo.reset_stock!
      vo.reload.count_on_hand.should == 12
    end
  end

  context "extends LocalizedNumber" do
    it_behaves_like "a model using the LocalizedNumber module", [:price]
  end

  context "changing stock levels via orders" do
    let(:hub) { create(:distributor_enterprise, with_payment_and_shipping: true) }
    let(:producer) { create(:supplier_enterprise) }
    let(:oc) { create(:simple_order_cycle, suppliers: [producer], coordinator: hub, distributors: [hub]) }
    let(:outgoing_exchange) { oc.exchanges.outgoing.first }
    let(:sm) { hub.shipping_methods.first }
    let(:pm) { hub.payment_methods.first }
    let(:p1) { create(:simple_product, supplier: producer) }
    let(:p2) { create(:simple_product, supplier: producer) }

    let(:v1) { create(:variant, product: p1, count_on_hand: 11) }
    let(:v2) { create(:variant, product: p1, count_on_hand: 12) }
    let(:v3) { create(:variant, product: p1, count_on_hand: 13) }
    let(:v4) { create(:variant, product: p2, count_on_hand: 14) }

    # vo1 overrides stock
    let!(:vo1) { create(:variant_override, variant: v1, count_on_hand: 21, hub: hub, default_stock: nil, resettable: false) }
    # vo2 does NOT override stock
    let!(:vo2) { create(:variant_override, variant: v2, count_on_hand: nil, hub: hub, default_stock: nil, resettable: false) }
    # vo3 overrides on_demand to true
    let!(:vo3) { create(:variant_override, variant: v3, count_on_hand: 23, on_demand: true, hub: hub, default_stock: nil, resettable: false) }

    let(:address) { create(:address) }

    before do
      outgoing_exchange.variants = [v1, v2, v3, v4]
      create(:mail_method)
    end

    describe "placing an order" do
      let(:order) { create(:order, distributor: hub, order_cycle: oc) }
      let(:li1) { create(:line_item, quantity: 1, order: order, variant: v1) } # VO overrides stock to 21 (from 11)
      let(:li2) { create(:line_item, quantity: 2, order: order, variant: v2) } # VO does not override stock (from 12)
      let(:li3) { create(:line_item, quantity: 3, order: order, variant: v3) } # VO overrides stock to 23 (from 13) AND sets on_demand: true
      let(:li4) { create(:line_item, quantity: 4, order: order, variant: v4) } # This is a simple variant with no overide

      before do
        order.line_items << [li1, li2, li3, li4]
        order.shipping_method = create(:shipping_method)
        order.bill_address = address
        order.ship_address = address
      end

      it "correctly decrements stock levels on order completion" do
        complete_order!

        expect(Spree::Variant.find(v1).count_on_hand).to eq 11 # Ordered 1, stock overridden
        expect(Spree::Variant.find(v2).count_on_hand).to eq 10 # Ordered 2, stock  NOT overridden
        expect(Spree::Variant.find(v3).count_on_hand).to eq 13 # Ordered 3, stock overridden and on_demand set
        expect(Spree::Variant.find(v4).count_on_hand).to eq 10 # Ordered 4, simple variant

        expect(vo1.reload.count_on_hand).to eq 20 # Ordered 1, stock overridden
        expect(vo2.reload.count_on_hand).to eq nil # Ordered 2, stock NOT overridden
        expect(vo3.reload.count_on_hand).to eq 23 # Ordered 3, stock overridden and on_demand set
      end

      it "correctly resets stock levels when an order is cancelled" do
        complete_order!
        order.cancel!

        expect(Spree::Variant.find(v1).count_on_hand).to eq 11
        expect(Spree::Variant.find(v2).count_on_hand).to eq 12
        expect(Spree::Variant.find(v3).count_on_hand).to eq 13
        expect(Spree::Variant.find(v4).count_on_hand).to eq 14

        expect(vo1.reload.count_on_hand).to eq 21
        expect(vo2.reload.count_on_hand).to eq nil
        expect(vo3.reload.count_on_hand).to eq 23
      end

      it "does not correctly reset stock levels if variant_overrides are changed, then an order is cancelled" do
        # An order is placed by a customer of a hub
        complete_order!

        # Two days later, the hub manager changes their variant overrides
        vo1.destroy
        vo2.destroy
        vo3.destroy

        # The order is cancelled at some time after that point
        order.reload.cancel!

        # Stock levels of variants belonging to "Producer X" are now incorrectly altered as
        # a consequence of "Hub Y" updating their inventory and an order being cancelled.
        # This is because the line_item on the order has no idea if it decremented the variant
        # from "Producer X", or the variant_override from "Hub Y" at the time the order was placed.

        expect(Spree::Variant.find(v1).count_on_hand).to eq 12 # This variant has been incorrectly restocked
        expect(Spree::Variant.find(v2).count_on_hand).to eq 12 # The VO didn't the stock in this case, so this is actually correct
        expect(Spree::Variant.find(v3).count_on_hand).to eq 16 # This variant has been incorrectly restocked
        expect(Spree::Variant.find(v4).count_on_hand).to eq 14 # Simple variant, fine
      end
    end
  end

  private

  def complete_order!
    order.state = "complete"
    order.finalize!
  end
end

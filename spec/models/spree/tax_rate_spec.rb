# frozen_string_literal: true

require 'spec_helper'

module Spree
  describe TaxRate do
    describe "selecting tax rates to apply to an order" do
      let!(:zone) { create(:zone_with_member) }
      let!(:order) { create(:order, distributor: hub, bill_address: create(:address)) }
      let!(:tax_rate) { create(:tax_rate, included_in_price: true, calculator: ::Calculator::FlatRate.new(preferred_amount: 0.1), zone: zone) }

      describe "when the order's hub charges sales tax" do
        let(:hub) { create(:distributor_enterprise, charges_sales_tax: true) }

        it "selects all tax rates" do
          expect(TaxRate.match(order)).to eq([tax_rate])
        end
      end

      describe "when the order's hub does not charge sales tax" do
        let(:hub) { create(:distributor_enterprise, charges_sales_tax: false) }

        it "selects no tax rates" do
          expect(TaxRate.match(order)).to be_empty
        end
      end

      describe "when the order does not have a hub" do
        let!(:order) { create(:order, distributor: nil, bill_address: create(:address)) }

        it "selects all tax rates" do
          expect(TaxRate.match(order)).to eq([tax_rate])
        end
      end
    end

    describe "ensuring that tax rate is marked as tax included_in_price" do
      let(:tax_rate) { create(:tax_rate, included_in_price: false, calculator: ::Calculator::DefaultTax.new) }

      it "sets included_in_price to true" do
        tax_rate.send(:with_tax_included_in_price) do
          expect(tax_rate.included_in_price).to be true
        end
      end

      it "sets the included_in_price value accessible to the calculator to true" do
        tax_rate.send(:with_tax_included_in_price) do
          expect(tax_rate.calculator.calculable.included_in_price).to be true
        end
      end

      it "passes through the return value of the block" do
        expect(tax_rate.send(:with_tax_included_in_price) do
          'asdf'
        end).to eq('asdf')
      end

      it "restores both values to their original afterwards" do
        tax_rate.send(:with_tax_included_in_price) {}
        expect(tax_rate.included_in_price).to be false
        expect(tax_rate.calculator.calculable.included_in_price).to be false
      end

      it "restores both values when an exception is raised" do
        expect do
          tax_rate.send(:with_tax_included_in_price) { raise StandardError, 'oops' }
        end.to raise_error 'oops'

        expect(tax_rate.included_in_price).to be false
        expect(tax_rate.calculator.calculable.included_in_price).to be false
      end
    end

    context "original Spree::TaxRate specs" do
      # These "match" specs were imported in the previous commit but some are failing and need looking at.
      # The failures relate to the two different setups where tax is either included or excluded.
      # It's not clear how much we have modified this class and how much these specs are still relevant.
      pending "match" do
        let(:order) { create(:order) }
        let(:country) { create(:country) }
        let(:tax_category) { create(:tax_category) }
        let(:calculator) { ::Calculator::FlatRate.new }

        it "should return an empty array when tax_zone is nil" do
          allow(order).to receive(:tax_zone) { nil }
          expect(Spree::TaxRate.match(order)).to eq []
        end

        context "when no rate zones match the tax zone" do
          before do
            Spree::TaxRate.create(amount: 1, zone: create(:zone))
          end

          context "when there is no default tax zone" do
            before do
              @zone = create(:zone, name: "Country Zone", default_tax: false, zone_members: [])
              @zone.zone_members.create(zoneable: country)
            end

            it "should return an empty array" do
              order.stub tax_zone: @zone
              expect(Spree::TaxRate.match(order)).to eq []
            end

            it "should return the rate that matches the rate zone" do
              rate = Spree::TaxRate.create(
                amount: 1,
                zone: @zone,
                tax_category: tax_category,
                calculator: calculator
              )

              order.stub tax_zone: @zone
              expect(Spree::TaxRate.match(order)).to eq [rate]
            end

            it "should return all rates that match the rate zone" do
              rate1 = Spree::TaxRate.create(
                amount: 1,
                zone: @zone,
                tax_category: tax_category,
                calculator: calculator
              )

              rate2 = Spree::TaxRate.create(
                amount: 2,
                zone: @zone,
                tax_category: tax_category,
                calculator: ::Calculator::FlatRate.new
              )

              order.stub tax_zone: @zone
              expect(Spree::TaxRate.match(order)).to eq [rate1, rate2]
            end

            context "when the tax_zone is contained within a rate zone" do
              before do
                sub_zone = create(:zone, name: "State Zone", zone_members: [])
                sub_zone.zone_members.create(zoneable: create(:state, country: country))
                order.stub tax_zone: sub_zone
                @rate = Spree::TaxRate.create(
                  amount: 1,
                  zone: @zone,
                  tax_category: tax_category,
                  calculator: calculator
                )
              end

              it "should return the rate zone" do
                expect(Spree::TaxRate.match(order)).to eq [@rate]
              end
            end
          end

          context "when there is a default tax zone" do
            before do
              @zone = create(:zone, name: "Country Zone", default_tax: true, zone_members: [])
              @zone.zone_members.create(zoneable: country)
            end

            let(:included_in_price) { false }
            let!(:rate) do
              Spree::TaxRate.create(amount: 1,
                                    zone: @zone,
                                    tax_category: tax_category,
                                    calculator: calculator,
                                    included_in_price: included_in_price)
            end

            subject { Spree::TaxRate.match(order) }

            context "when the order has the same tax zone" do
              before do
                order.stub tax_zone: @zone
                order.stub billing_address: tax_address
              end

              let(:tax_address) { build_stubbed(:address) }

              context "when the tax is not a VAT" do
                it { is_expected.to eq [rate] }
              end

              context "when the tax is a VAT" do
                let(:included_in_price) { true }
                it { expect(subject).to be_empty }
              end
            end

            context "when there order has a different tax zone" do
              before do
                order.stub tax_zone: create(:zone, name: "Other Zone")
                order.stub billing_address: tax_address
              end

              context "when the order has a tax_address" do
                let(:tax_address) { build_stubbed(:address) }

                context "when the tax is a VAT" do
                  let(:included_in_price) { true }
                  it { is_expected.to eq [rate] }
                end

                context "when the tax is not VAT" do
                  it "returns no tax rate" do
                    expect(subject).to be_empty
                  end
                end
              end

              context "when the order does not have a tax_address" do
                let(:tax_address) { nil }

                context "when the tax is not a VAT" do
                  let(:included_in_price) { true }
                  it { is_expected.to be_empty }
                end

                context "when the tax is not a VAT" do
                  it { is_expected.to eq [rate] }
                end
              end
            end
          end
        end
      end

      context "adjust" do
        let(:order) { build_stubbed(:order) }
        let(:rate_1) { build_stubbed(:tax_rate) }
        let(:rate_2) { build_stubbed(:tax_rate) }
        let(:line_items) { [build_stubbed(:line_item)] }

        before do
          allow(Spree::TaxRate).to receive(:match) { [rate_1, rate_2] }
        end

        it "should apply adjustments for two tax rates to the order" do
          expect(rate_1).to receive(:adjust)
          expect(rate_2).to receive(:adjust)
          Spree::TaxRate.adjust(order, line_items)
        end
      end

      context "default" do
        let(:tax_category) { create(:tax_category) }
        let(:country) { create(:country) }
        let(:calculator) { ::Calculator::FlatRate.new }

        context "when there is no default tax_category" do
          before { tax_category.is_default = false }

          it "should return 0" do
            expect(Spree::TaxRate.default).to eq 0
          end
        end

        context "when there is a default tax_category" do
          before { tax_category.update_column :is_default, true }

          context "when the default category has tax rates in the default tax zone" do
            before(:each) do
              Spree::Config[:default_country_id] = country.id
              @zone = create(:zone, name: "Country Zone", default_tax: true)
              @zone.zone_members.create(zoneable: country)
              rate = Spree::TaxRate.create(
                amount: 1,
                zone: @zone,
                tax_category: tax_category,
                calculator: calculator
              )
            end

            it "should return the correct tax_rate" do
              expect(Spree::TaxRate.default.to_f).to eq 1.0
            end
          end

          context "when the default category has no tax rates in the default tax zone" do
            it "should return 0" do
              expect(Spree::TaxRate.default).to eq 0
            end
          end
        end
      end

      context "#adjust" do
        before do
          @category    = Spree::TaxCategory.create(name: "Taxable Foo")
          @category2   = Spree::TaxCategory.create(name: "Non Taxable")
          @calculator  = ::Calculator::DefaultTax.new
          @rate        = Spree::TaxRate.create(
            amount: 0.10,
            calculator: @calculator,
            tax_category: @category
          )
          @order       = Spree::Order.create!
          @taxable     = create(:product, tax_category: @category)
          @nontaxable  = create(:product, tax_category: @category2)
        end

        context "not taxable line item " do
          let!(:line_item) { @order.contents.add(@nontaxable.master, 1) }

          it "should not create a tax adjustment" do
            @rate.adjust(@order, line_item)
            expect(line_item.adjustments.tax.charge.count).to eq 0
          end

          it "should not create a refund" do
            @rate.adjust(@order, line_item)
            expect(line_item.adjustments.credit.count).to eq 0
          end
        end

        context "taxable line item" do
          let!(:line_item) { @order.contents.add(@taxable.master, 1) }

          context "when price includes tax" do
            before { @rate.update_column(:included_in_price, true) }

            context "when zone is contained by default tax zone" do
              before { Spree::Zone.stub_chain :default_tax, contains?: true }

              it "should create one adjustment" do
                @rate.adjust(@order, line_item)
                expect(line_item.adjustments.count).to eq 1
              end

              it "should not create a tax refund" do
                @rate.adjust(@order, line_item)
                expect(line_item.adjustments.credit.count).to eq 0
              end
            end

            context "when zone is not contained by default tax zone" do
              before { Spree::Zone.stub_chain :default_tax, contains?: false }
              it "should not create an adjustment" do
                @rate.adjust(@order, line_item)
                expect(line_item.adjustments.charge.count).to eq 0
              end

              it "should create a tax refund" do
                @rate.adjust(@order, line_item)
                expect(line_item.adjustments.credit.count).to eq 1
              end
            end
          end

          context "when price does not include tax" do
            before { @rate.update_column(:included_in_price, false) }

            it "should create an adjustment" do
              @rate.adjust(@order, line_item)
              expect(line_item.adjustments.count).to eq 1
            end

            it "should not create a tax refund" do
              @rate.adjust(@order, line_item)
              expect(line_item.adjustments.credit.count).to eq 0
            end
          end
        end
      end
    end
  end
end

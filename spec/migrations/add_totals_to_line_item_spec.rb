# frozen_string_literal: true

require 'spec_helper'
require_relative '../../db/migrate/20210428152447_add_totals_to_line_item'

describe AddTotalsToLineItem do
  subject { AddTotalsToLineItem.new }

  let!(:zone) { create(:zone_with_member) }
  let(:tax_category) { create(:tax_category) }
  let(:tax_rate_included) { create(:tax_rate, tax_category: tax_category, included_in_price: true) }
  let(:tax_rate_additional) { create(:tax_rate, tax_category: tax_category, included_in_price: false) }
  let(:enterprise_fee) { create(:enterprise_fee) }
  let!(:line_item) { create(:line_item) }
  let(:additional_tax_adjustment) {
    create(:adjustment, amount: 10, originator: tax_rate_additional,
                        adjustable: line_item, state: "finalized")
  }
  let(:included_tax_adjustment1) {
    create(:adjustment, amount: 20, originator: tax_rate_included,
                        adjustable: line_item, state: "finalized", included: true)
  }
  let(:included_tax_adjustment2) {
    create(:adjustment, amount: 50, originator: tax_rate_included,
                        adjustable: line_item, state: "finalized", included: true)
  }
  let(:enterprise_fee_adjustment) {
    create(:adjustment, amount: 40, originator: enterprise_fee,
                        adjustable: line_item, state: "finalized")
  }
  let(:enterprise_fee_tax_adjustment) {
    create(:adjustment, amount: 5, originator: tax_rate_included,
                        adjustable: enterprise_fee_adjustment, state: "finalized")
  }

  describe '#populate_adjustment_totals' do
    context "with fees" do
      before do
        enterprise_fee_adjustment
        clear_totals
      end

      it "records fees in adjustment_total" do
        subject.populate_adjustment_totals

        line_item.reload

        expect(line_item.included_tax_total).to eq 0
        expect(line_item.additional_tax_total).to eq 0
        expect(line_item.adjustment_total).to eq 40
      end
    end

    context "with additional tax and fees" do
      before do
        additional_tax_adjustment
        enterprise_fee_adjustment
        clear_totals
      end

      it "combines additional tax total and fees total in adjustment_total" do
        subject.populate_adjustment_totals

        line_item.reload

        expect(line_item.included_tax_total).to eq 0
        expect(line_item.additional_tax_total).to eq 10
        expect(line_item.adjustment_total).to eq 50
      end
    end

    context "with included taxes" do
      before do
        included_tax_adjustment1
        included_tax_adjustment2
        clear_totals
      end

      it "totals included tax" do
        subject.populate_adjustment_totals

        line_item.reload

        expect(line_item.included_tax_total).to eq 70
        expect(line_item.additional_tax_total).to eq 0
        expect(line_item.adjustment_total).to eq 0
      end
    end

    context "with tax, fees, and tax on fees" do
      before do
        included_tax_adjustment1
        enterprise_fee_adjustment
        enterprise_fee_tax_adjustment
        clear_totals
      end

      it "includes fees but doesn't include tax on fees" do
        subject.populate_adjustment_totals

        line_item.reload

        expect(line_item.included_tax_total).to eq 20
        expect(line_item.additional_tax_total).to eq 0
        expect(line_item.adjustment_total).to eq 40
      end
    end
  end

  private

  def clear_totals
    line_item.update_columns(
      included_tax_total: 0,
      additional_tax_total: 0,
      adjustment_total: 0
    )
  end
end

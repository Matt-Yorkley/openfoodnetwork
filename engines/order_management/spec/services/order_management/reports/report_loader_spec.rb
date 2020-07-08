# frozen_string_literal: true

require 'spec_helper'

module OrderManagement
  module Reports
    module Bananas
      class Base; end
      class Green; end
      class Yellow; end
    end
  end
end

module OrderManagement
  module Reports
    describe ReportLoader do
      let(:service) { OrderManagement::Reports::ReportLoader.new(*arguments) }
      let(:report_base_class) { OrderManagement::Reports::Bananas::Base }
      let(:report_subtypes) { ["green", "yellow"] }

      before do
        allow(report_base_class).to receive(:report_subtypes).and_return(report_subtypes)
      end

      describe "#report_class" do
        describe "given report type and subtype" do
          let(:arguments) { ["bananas", "yellow"] }

          it "returns a report class when given type and subtype" do
            expect(service.report_class).to eq OrderManagement::Reports::Bananas::Yellow
          end
        end

        describe "given report type only" do
          context "when the report has multiple subtypes" do
            let(:arguments) { ["bananas"] }

            it "returns first listed report type" do
              expect(service.report_class).to eq OrderManagement::Reports::Bananas::Green
            end
          end

          context "when the report has no subtypes" do
            let(:arguments) { ["bananas"] }
            let(:report_subtypes) { [] }

            it "returns base class" do
              expect(service.report_class).to eq OrderManagement::Reports::Bananas::Base
            end
          end

          context "given a report type that does not exist" do
            let(:arguments) { ["apples"] }
            let(:report_subtypes) { [] }

            it "raises and error" do
              expect{service.report_class}.to raise_error(
                OrderManagement::Errors::ReportNotFound
              )
            end
          end
        end
      end

      describe "#default_report_subtype" do
        context "when the report has multiple subtypes" do
          let(:arguments) { ["bananas"] }

          it "returns the first report type" do
            expect(service.default_report_subtype).to eq report_base_class.report_subtypes.first
          end
        end

        context "when the report has no subtypes" do
          let(:arguments) { ["bananas"] }
          let(:report_subtypes) { [] }

          it "returns base" do
            expect(service.default_report_subtype).to eq "base"
          end
        end

        context "given a report type that does not exist" do
          let(:arguments) { ["apples"] }
          let(:report_subtypes) { [] }

          it "raises and error" do
            expect{service.report_class}.to raise_error(
              OrderManagement::Errors::ReportNotFound
            )
          end
        end
      end

      describe "#report_subtypes" do
        context "when the report has multiple subtypes" do
          let(:arguments) { ["bananas"] }

          it "returns a list of report subtypes for a given report" do
            expect(service.report_subtypes).to eq report_subtypes
          end
        end

        context "when the report has no subtypes" do
          let(:arguments) { ["bananas"] }
          let(:report_subtypes) { [] }

          it "returns an empty array" do
            expect(service.report_subtypes).to eq []
          end
        end
      end
    end
  end
end
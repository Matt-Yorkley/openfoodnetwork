require 'spec_helper'

describe CacheService do
  let(:rails_cache) { Rails.cache }

  describe "#cache" do
    before do
      rails_cache.stub(:fetch)
    end

    it "provides a wrapper for basic #fetch calls to Rails.cache" do
      CacheService.cache("test-cache-key", expires_in: 10.seconds) do
        "TEST"
      end

      expect(rails_cache).to have_received(:fetch).with("test-cache-key", expires_in: 10.seconds)
    end
  end

  describe "#cached_data_by_class" do
    let(:timestamp) { Time.now.to_i }

    before do
      rails_cache.stub(:fetch)
      CacheService.stub(:latest_timestamp_by_class) { timestamp }
    end

    it "caches data by timestamp for last record of that class" do
      CacheService.cached_data_by_class("test-cache-key", Enterprise) do
        "TEST"
      end

      expect(CacheService).to have_received(:latest_timestamp_by_class).with(Enterprise)
      expect(rails_cache).to have_received(:fetch).with("test-cache-key-Enterprise-#{timestamp}")
    end
  end

  describe "#latest_timestamp_by_class" do
    let!(:taxon1) { create(:taxon) }
    let!(:taxon2) { create(:taxon) }

    it "gets the :updated_at value of the last record for a given class and returns a timestamp" do
      taxon1.touch
      expect(CacheService.latest_timestamp_by_class(Spree::Taxon)).to eq taxon1.updated_at.to_i

      taxon2.touch
      expect(CacheService.latest_timestamp_by_class(Spree::Taxon)).to eq taxon2.updated_at.to_i
    end
  end
end

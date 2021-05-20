# frozen_string_literal: true

module Api
  module Admin
    class TaxonSerializer < ActiveModel::Serializer
      cached
      delegate :cache_key, to: :object

      attributes :id, :name
    end
  end
end

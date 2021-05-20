class Api::TaxonSerializer < ActiveModel::Serializer
  cached
  delegate :cache_key, to: :object

  attributes :id, :name, :permalink, :position, :parent_id, :taxonomy_id
end

class Spree::Api::ProductSerializer < ActiveModel::Serializer
  attributes :id, :name, :variant_unit, :variant_unit_scale, :variant_unit_name, :on_demand

  attributes :taxon_ids, :on_hand, :price, :available_on, :permalink_live
  
  has_one :supplier, key: :producer, embed: :id
  has_many :variants, key: :variants, serializer: Spree::Api::VariantSerializer # embed: ids
  has_one :master, serializer: Spree::Api::VariantSerializer
  
  # Infinity is not a valid JSON object, but Rails encodes it anyway
  def taxon_ids
    object.taxons.map{ |t| t.id }.join(",")
  end
  
  def on_hand
    object.on_hand.nil? ? 0 : object.on_hand.to_f.finite? ? object.on_hand : "On demand"
  end
  
  def price
    object.price.nil? ? '0.0' : object.price
  end
  
  def available_on
    object.available_on.blank? ? "" : object.available_on.strftime("%F %T")
  end
  
  def permalink_live
    object.permalink
  end
end
module SerializerHelper
  def ids_to_objs(ids)
    return [] if ids.blank?
    ids.map { |id| {id: id} }
  end

  # Returns an array of the attributes a serializer needs from it's object
  # so we can #select the fields that the serializer will actually use
  def self.required_attributes(model, serializer)
    model_attributes = model.attribute_names
    serializer_attributes = serializer._attributes.keys.map(&:to_sym)

    serializer_attributes & model_attributes
  end
end

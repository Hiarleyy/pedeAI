module TextEncodingValidatable
  extend ActiveSupport::Concern

  included do
    class_attribute :text_encoding_attributes, instance_accessor: false, default: []
    validate :text_encoding_is_valid
  end

  class_methods do
    def validates_text_encoding(*attributes)
      self.text_encoding_attributes = (text_encoding_attributes + attributes.map(&:to_sym)).uniq
    end
  end

  private

  def text_encoding_is_valid
    self.class.text_encoding_attributes.each do |attribute|
      paths = TextEncodingHealth.suspicious_paths(public_send(attribute), attribute.to_s)
      next if paths.empty?

      location = paths.first.delete_prefix("#{attribute}.")
      errors.add(attribute, "contém caracteres com codificação corrompida#{location == attribute.to_s ? "" : " em #{location}"}")
    end
  end
end

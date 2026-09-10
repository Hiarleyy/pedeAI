class TextEncodingHealth
  SUSPICIOUS_SEQUENCE = /\uFFFD|\u00C3[\u0080-\u00BF]|\u00C2[\u0080-\u00BF]|\u00E2[\u0080-\u00BF]|\u00F0[\u0080-\u00BF]/.freeze

  class << self
    def suspicious?(value)
      value.is_a?(String) && value.match?(SUSPICIOUS_SEQUENCE)
    end

    def suspicious_paths(value, path = nil)
      case value
      when String
        suspicious?(value) ? [path || "value"] : []
      when Hash
        value.flat_map do |key, nested_value|
          key_path = [path, key].compact.join(".")
          paths = suspicious?(key.to_s) ? ["#{key_path} (chave)"] : []
          paths + suspicious_paths(nested_value, key_path)
        end
      when Array
        value.each_with_index.flat_map { |nested_value, index| suspicious_paths(nested_value, "#{path}[#{index}]") }
      else
        []
      end
    end
  end
end

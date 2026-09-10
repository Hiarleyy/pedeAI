require_relative "concerns/text_encoding_validatable"

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include ::TextEncodingValidatable
end

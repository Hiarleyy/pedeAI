ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "base64"
require "tempfile"

module ProductImageTestHelper
  PNG_BYTES = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  ).freeze

  def uploaded_png(filename: "product.png", content_type: "image/png", bytes: PNG_BYTES)
    tempfile = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.rewind
    (@uploaded_image_tempfiles ||= []) << tempfile
    Rack::Test::UploadedFile.new(tempfile.path, content_type, true, original_filename: filename)
  end

  def cleanup_uploaded_image_tempfiles
    Array(@uploaded_image_tempfiles).each(&:close!)
    @uploaded_image_tempfiles = []
  end
end

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  include ProductImageTestHelper
  teardown :cleanup_uploaded_image_tempfiles
end

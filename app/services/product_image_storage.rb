require "fileutils"
require "marcel"
require "pathname"
require "securerandom"
require "set"

class ProductImageStorage
  MAX_SIZE = 2.megabytes
  TYPES = {
    "image/png" => ".png",
    "image/jpeg" => ".jpg",
    "image/webp" => ".webp"
  }.freeze
  MANAGED_PREFIX = "/uploads/products/"
  MANAGED_FILENAME = /\Arestaurant-\d+-product-\d+-[a-f0-9]{16}\.(?:png|jpg|webp)\z/

  StoredImage = Data.define(:url, :path)

  class InvalidImage < StandardError; end

  attr_reader :directory

  def initialize(directory: Rails.root.join("public", "uploads", "products"))
    @directory = Pathname.new(directory).expand_path
  end

  def validate!(upload)
    declared_type = upload.respond_to?(:content_type) ? upload.content_type.to_s.downcase : ""
    detected_type = detected_type_for(upload)
    valid_size = upload.respond_to?(:size) && upload.size.positive? && upload.size <= MAX_SIZE

    return detected_type if valid_size && TYPES.key?(declared_type) && declared_type == detected_type

    raise InvalidImage, "Imagem inválida. Use PNG, JPEG ou WebP de até 2 MB."
  end

  def store!(upload, restaurant_id:, product_id:)
    mime_type = validate!(upload)
    FileUtils.mkdir_p(directory)
    filename = "restaurant-#{Integer(restaurant_id)}-product-#{Integer(product_id)}-#{SecureRandom.hex(8)}#{TYPES.fetch(mime_type)}"
    path = directory.join(filename)

    begin
      File.binwrite(path, File.binread(upload.tempfile.path))
    rescue StandardError
      File.delete(path) if path.file?
      raise
    end

    StoredImage.new("#{MANAGED_PREFIX}#{filename}", path)
  end

  def delete_url!(url)
    path = path_for(url)
    return false unless path&.file?

    File.delete(path)
    true
  rescue Errno::ENOENT
    false
  end

  def orphan_urls(referenced_urls)
    references = Array(referenced_urls).select { |url| managed_url?(url) }.to_set
    managed_files.map { |path| "#{MANAGED_PREFIX}#{path.basename}" }.reject { |url| references.include?(url) }.sort
  end

  def delete_orphans!(referenced_urls)
    orphan_urls(referenced_urls).select { |url| delete_url!(url) }
  end

  private

  def detected_type_for(upload)
    return "" unless upload.respond_to?(:tempfile) && upload.tempfile.respond_to?(:path)

    Marcel::MimeType.for(Pathname.new(upload.tempfile.path), name: nil, declared_type: nil).to_s.downcase
  rescue Errno::ENOENT, IOError
    ""
  end

  def managed_files
    return [] unless directory.directory?

    directory.children.select { |path| path.file? && path.basename.to_s.match?(MANAGED_FILENAME) }
  end

  def managed_url?(url)
    url.to_s.start_with?(MANAGED_PREFIX) && File.basename(url.to_s).match?(MANAGED_FILENAME)
  end

  def path_for(url)
    return unless managed_url?(url)

    path = directory.join(File.basename(url.to_s)).expand_path
    path if path.dirname == directory
  end
end

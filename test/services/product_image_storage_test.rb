require "test_helper"
require "fileutils"
require "tmpdir"

class ProductImageStorageTest < ActiveSupport::TestCase
  setup do
    @directory = Pathname.new(Dir.mktmpdir("product-images"))
    @storage = ProductImageStorage.new(directory: @directory)
  end

  teardown do
    FileUtils.remove_entry(@directory) if @directory&.exist?
  end

  test "armazena imagem usando o tipo real validado pelo Marcel" do
    stored = @storage.store!(uploaded_png, restaurant_id: 7, product_id: 12)

    assert_equal "image/png", Marcel::MimeType.for(stored.path)
    assert_match %r{\A/uploads/products/restaurant-7-product-12-[a-f0-9]{16}\.png\z}, stored.url
    assert stored.path.exist?
  end

  test "rejeita divergência entre MIME declarado e conteúdo real" do
    upload = uploaded_png(filename: "foto.jpg", content_type: "image/jpeg")

    error = assert_raises(ProductImageStorage::InvalidImage) { @storage.validate!(upload) }

    assert_includes error.message, "Imagem inválida"
    assert_empty @directory.children
  end

  test "reconciliação limita candidatos a arquivos gerenciados e nunca inclui referenciados" do
    referenced = "/uploads/products/restaurant-1-product-10-aaaaaaaaaaaaaaaa.png"
    orphan = "/uploads/products/restaurant-1-product-11-bbbbbbbbbbbbbbbb.jpg"
    unrelated = @directory.join("manual.jpg")
    referenced_path = @directory.join(File.basename(referenced))
    orphan_path = @directory.join(File.basename(orphan))
    File.binwrite(referenced_path, ProductImageTestHelper::PNG_BYTES)
    File.binwrite(orphan_path, ProductImageTestHelper::PNG_BYTES)
    File.binwrite(unrelated, ProductImageTestHelper::PNG_BYTES)

    assert_equal [orphan], @storage.orphan_urls([referenced])
    assert orphan_path.exist?, "o modo relatório não deve remover arquivos"

    assert_equal [orphan], @storage.delete_orphans!([referenced])
    assert referenced_path.exist?
    assert unrelated.exist?
    assert_not orphan_path.exist?
  end
end

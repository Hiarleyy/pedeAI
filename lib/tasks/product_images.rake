namespace :product_images do
  desc "Reporta imagens de produtos sem referência; use DELETE=true para removê-las"
  task reconcile: :environment do
    storage = ProductImageStorage.new
    referenced_urls = Product.where.not(image_url: nil).pluck(:image_url)
    orphan_urls = storage.orphan_urls(referenced_urls)
    delete = ActiveModel::Type::Boolean.new.cast(ENV["DELETE"])

    if orphan_urls.empty?
      puts "Nenhuma imagem órfã encontrada."
      next
    end

    puts "#{orphan_urls.length} imagem(ns) órfã(s):"
    orphan_urls.each { |url| puts url }

    if delete
      removed = storage.delete_orphans!(referenced_urls)
      puts "#{removed.length} imagem(ns) removida(s)."
    else
      puts "Modo relatório: nenhum arquivo foi removido. Use DELETE=true após revisar a lista."
    end
  end
end

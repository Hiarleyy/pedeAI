namespace :pricing do
  desc "Lista variações suspeitas abaixo do preço base sem alterar dados"
  task audit_variants: :environment do
    records = SuspiciousVariantPriceAudit.call
    puts "Variações suspeitas: #{records.size}"
    records.each do |variant|
      product = variant.product
      puts "#{product.restaurant.slug} | #{product.name} | base=#{product.price} | #{variant.name}=#{variant.price}"
    end
  end
end

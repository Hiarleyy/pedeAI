namespace :text_encoding do
  desc "Relata registros com sequências de texto corrompidas"
  task audit: :environment do
    findings = TextEncodingAudit.new.findings
    if findings.empty?
      puts "Nenhum registro com codificação suspeita encontrado."
      next
    end

    puts "#{findings.length} ocorrência(s) com codificação suspeita:"
    findings.each do |finding|
      puts "#{finding.model} id=#{finding.id} #{finding.attribute}: #{finding.paths.join(', ')}"
    end
  end

  desc "Repara somente o produto legado cujo nome e descrição correspondem exatamente ao padrão conhecido"
  task repair_known: :environment do
    abort "Modo seguro: execute APPLY=true rake text_encoding:repair_known para aplicar o reparo conhecido." unless ActiveModel::Type::Boolean.new.cast(ENV["APPLY"])

    repaired = TextEncodingAudit.new.repair_known!
    puts "#{repaired} produto(s) legado(s) reparado(s)."
  end
end

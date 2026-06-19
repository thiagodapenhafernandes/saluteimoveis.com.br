namespace :empreendimentos do
  desc "Normaliza variantes de nome de empreendimento (ex.: com/sem 'Edifício', 'Tower'). " \
       "Por padrão DRY-RUN (só gera CSV para revisão). Use APPLY=true para unificar de fato."
  task normalizar_nomes: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV.fetch("APPLY", "false"))
    result = Empreendimentos::NameNormalizationService.new(apply: apply).call

    puts "Normalização de nomes de empreendimento"
    puts "  grupos com variantes: #{result.clusters_total}"
    puts "  variantes no total:   #{result.variants_total}"
    puts "  registros atualizados: #{result.records_updated}"
    puts "  relatório (revise antes de aplicar): #{result.report_path}"
    puts "  modo: #{apply ? 'APPLY (gravou no banco)' : 'DRY-RUN (nada gravado)'}"
    puts ""
    puts "Prévia dos 15 maiores grupos:" unless apply
    unless apply
      result.clusters.sort_by { |c| -c[:variants].size }.first(15).each do |cluster|
        puts "  → canônico: #{cluster[:canonical].inspect}"
        cluster[:variants].each do |variant|
          marker = variant == cluster[:canonical] ? "✔" : " "
          puts "      #{marker} #{variant.inspect} (#{cluster[:counts][variant]} registros)"
        end
      end
      puts ""
      puts "Fluxo recomendado:"
      puts "  1) Revise/edite a coluna 'nome_canonico' no CSV (a proposta automática pode errar)."
      puts "  2) Aplique a partir do CSV revisado:"
      puts "     bundle exec rake empreendimentos:aplicar_nomes FILE=#{result.report_path}"
      puts "  3) Rode a sincronização de hierarquia para alinhar unidades aos pais."
    end
  end

  desc "Aplica a normalização de nomes a partir de um CSV revisado (colunas: variante, nome_canonico). FILE=caminho.csv"
  task aplicar_nomes: :environment do
    file = ENV["FILE"].presence || Rails.root.join("tmp", "reports", "empreendimentos_variantes.csv").to_s
    abort("Arquivo não encontrado: #{file}") unless File.exist?(file)

    summary = Empreendimentos::NameNormalizationService.apply_from_csv(file)

    puts "Aplicação da normalização (CSV revisado)"
    puts "  arquivo: #{file}"
    puts "  linhas aplicadas: #{summary[:rows_applied]}"
    puts "  registros atualizados: #{summary[:records_updated]}"
  end
end

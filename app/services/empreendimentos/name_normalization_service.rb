# frozen_string_literal: true

require "csv"
require "fileutils"

module Empreendimentos
  # Agrupa variantes de grafia do mesmo empreendimento (ver NameNormalizer) e,
  # opcionalmente (apply: true), unifica todos os registros para um nome canônico.
  # Por padrão roda em DRY-RUN: só monta os grupos e gera um CSV para revisão,
  # sem escrever nada no banco.
  class NameNormalizationService
    Result = Struct.new(
      :clusters, :clusters_total, :variants_total, :records_updated, :report_path, :applied,
      keyword_init: true
    )

    def initialize(apply: false)
      @apply = apply
    end

    def call
      now = Time.current
      name_counts = base_scope.group(:nome_empreendimento).count

      # Nome canônico preferido por chave: o do registro tipo=Empreendimento.
      canonical_by_key = Habitation.empreendimentos
                                   .where("NULLIF(TRIM(nome_empreendimento), '') IS NOT NULL AND nome_empreendimento != '.'")
                                   .pluck(:nome_empreendimento)
                                   .index_by { |name| NameNormalizer.key(name) }

      clusters = name_counts.keys
                            .group_by { |name| NameNormalizer.key(name) }
                            .select { |_key, names| names.uniq.size > 1 }
                            .map do |key, names|
        canonical = canonical_by_key[key].presence || NameNormalizer.canonical_for(names, counts: name_counts)
        {
          key: key,
          canonical: canonical,
          variants: names.uniq.sort,
          counts: name_counts.slice(*names)
        }
      end

      records_updated = 0
      if @apply
        clusters.each do |cluster|
          cluster[:variants].each do |variant|
            next if variant == cluster[:canonical]

            records_updated += Habitation
                               .where(nome_empreendimento: variant)
                               .update_all(nome_empreendimento: cluster[:canonical], updated_at: now)
          end
        end
      end

      Result.new(
        clusters: clusters,
        clusters_total: clusters.size,
        variants_total: clusters.sum { |c| c[:variants].size },
        records_updated: records_updated,
        report_path: write_report(clusters),
        applied: @apply
      )
    end

    # Aplica a partir de um CSV revisado manualmente (colunas: variante,
    # nome_canonico). Para cada linha, renomeia todos os imóveis com aquele nome
    # exato para o nome canônico informado. Seguro: ignora linhas em branco ou
    # onde a variante já é igual ao canônico.
    def self.apply_from_csv(path)
      now = Time.current
      updated = 0
      rows = 0

      CSV.foreach(path, headers: true) do |row|
        variant = row["variante"].to_s.strip
        canonical = row["nome_canonico"].to_s.strip
        next if variant.blank? || canonical.blank? || variant == canonical

        rows += 1
        updated += Habitation.where(nome_empreendimento: variant)
                             .update_all(nome_empreendimento: canonical, updated_at: now)
      end

      { rows_applied: rows, records_updated: updated }
    end

    private

    def base_scope
      Habitation.where("NULLIF(TRIM(nome_empreendimento), '') IS NOT NULL AND nome_empreendimento != '.'")
    end

    def write_report(clusters)
      dir = Rails.root.join("tmp", "reports")
      FileUtils.mkdir_p(dir)
      path = dir.join("empreendimentos_variantes.csv")

      CSV.open(path, "w") do |csv|
        csv << %w[chave nome_canonico variante registros]
        clusters.sort_by { |c| c[:canonical].to_s.downcase }.each do |cluster|
          cluster[:variants].each do |variant|
            csv << [cluster[:key], cluster[:canonical], variant, cluster[:counts][variant]]
          end
        end
      end

      path.to_s
    end
  end
end

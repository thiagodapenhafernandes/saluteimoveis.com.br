namespace :seo do
  desc "Atualiza SEO automático de páginas de imóveis a partir dos dados atuais dos imóveis"
  task backfill_property_settings: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "0"))
    result = Seo::PropertySettingsBackfill.new(dry_run: dry_run).call

    puts(
      [
        "seo:backfill_property_settings",
        "dry_run=#{dry_run}",
        "scanned=#{result.scanned}",
        "updated=#{result.updated}",
        "skipped_manual=#{result.skipped_manual}",
        "missing_habitation=#{result.missing_habitation}"
      ].join(" ")
    )
  end
end

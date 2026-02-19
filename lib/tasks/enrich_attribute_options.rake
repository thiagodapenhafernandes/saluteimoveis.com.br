namespace :enrich_attribute_options do
  desc "Migrate hardcoded Habitation constants to AttributeOption model"
  task perform: :environment do
    puts "Starting AttributeOption enrichment..."

    # 1. Feature Categories (Internal)
    Habitation::INTERNAL_FEATURES.each do |featuare|
      AttributeOption.find_or_create_by!(
        name: featuare, 
        category: 'feature', 
        context: 'habitation'
      )
    end
    puts "--> Migrated #{Habitation::INTERNAL_FEATURES.size} Internal Features."

    # 2. Infra/External Categories
    Habitation::EXTERNAL_FEATURES.each do |infra|
      AttributeOption.find_or_create_by!(
        name: infra, 
        category: 'infrastructure', 
        context: 'habitation'
      )
    end
    puts "--> Migrated #{Habitation::EXTERNAL_FEATURES.size} Infrastructure items."

    # 3. Unique Features (Badges) - Migrate from existing data
    # Since we just migrated to array, values might be empty or strings.
    # Safe approach: fetch all, flatten, uniq in Ruby (efficient enough for this dataset size)
    
    puts "fetching existing badges from database..."
    existing_badges = Habitation.pluck(:caracteristica_unica).flatten.compact.map(&:strip).reject(&:blank?).uniq
    
    defaults = ["Frente Mar", "Quadra Mar", "Decorado", "Mobiliado", "Vista Mar", "Lançamento", "Oportunidade", "Exclusividade"]
    all_badges = (existing_badges + defaults).uniq

    all_badges.each do |badge|
      AttributeOption.find_or_create_by!(
        name: badge, 
        category: 'unique_feature', 
        context: 'habitation'
      )
    end
    puts "--> Migrated #{all_badges.size} Unique Features (Badges)."

    puts "AttributeOption enrichment completed successfully!"
  end
end

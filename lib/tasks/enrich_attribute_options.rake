namespace :enrich_attribute_options do
  desc "Migrate hardcoded Habitation constants to AttributeOption model"
  task perform: :environment do
    puts "Starting AttributeOption enrichment..."

    internal_features = if Habitation.respond_to?(:internal_features)
      Habitation.internal_features
    elsif Habitation.respond_to?(:const_defined?) && Habitation.const_defined?(:INTERNAL_FEATURES)
      Habitation::INTERNAL_FEATURES
    else
      []
    end

    external_features = if Habitation.respond_to?(:external_features)
      Habitation.external_features
    elsif Habitation.respond_to?(:const_defined?) && Habitation.const_defined?(:EXTERNAL_FEATURES)
      Habitation::EXTERNAL_FEATURES
    else
      []
    end

    # 1. Feature Categories (Internal)
    internal_features.each do |feature|
      AttributeOption.find_or_create_by!(
        name: feature, 
        category: 'feature', 
        context: 'habitation'
      )
    end
    puts "--> Migrated #{internal_features.size} Internal Features."

    # 2. Infra/External Categories
    external_features.each do |infra|
      AttributeOption.find_or_create_by!(
        name: infra, 
        category: 'infrastructure', 
        context: 'habitation'
      )
    end
    puts "--> Migrated #{external_features.size} Infrastructure items."

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

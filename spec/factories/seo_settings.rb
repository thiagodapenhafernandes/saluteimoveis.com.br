FactoryBot.define do
  factory :seo_setting do
    sequence(:page_name) { |n| "seo-page-#{n}" }
    sequence(:canonical_key) { |n| "seo-page-#{n}" }
    page_type { "generic" }
    controller_name { "pages" }
    action_name { "show" }
    canonical_path { "/" }
    normalized_params { {} }
    meta_title { "Título SEO" }
    meta_description { "Descrição SEO" }
    og_title { "Título social" }
    og_description { "Descrição social" }
    robots_index { true }
    robots_follow { true }
    active { true }
    apply_to_public { true }
    manual_mode { false }
    auto_discovered { true }
    ai_status { "pending" }
  end
end

FactoryBot.define do
  factory :habitation do
    sequence(:codigo) { |n| (8000 + n).to_s }
    categoria { "Casa em Condomínio" }
    tipo { "Unitário" }
    status { "Venda" }
    exibir_no_site_flag { true }
    valor_venda_cents { 990_000_000 }
    valor_locacao_cents { 0 }
    pictures do
      [
        {
          "url" => "https://example.com/property.jpg",
          "ordem" => 1,
          "principal" => true
        }
      ]
    end

    trait :unavailable do
      exibir_no_site_flag { false }
    end
  end
end

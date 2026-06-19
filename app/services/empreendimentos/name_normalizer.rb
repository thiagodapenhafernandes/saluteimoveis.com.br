# frozen_string_literal: true

module Empreendimentos
  # Normaliza nomes de empreendimento para agrupar variantes do mesmo prédio
  # (ex.: "Edifício Grand Place", "Grand Place Tower" e "Edifício Grand Place
  # Tower" caem no mesmo grupo). NÃO ordena tokens (preserva a ordem das
  # palavras) para evitar fundir nomes diferentes.
  module NameNormalizer
    # Palavras "de ruído" que costumam variar sem mudar o empreendimento.
    NOISE_TOKENS = %w[
      edificio edif ed
      residencial resid res
      condominio cond
      predio
      torre tower
      bloco
    ].freeze

    module_function

    # Chave de agrupamento: sem acento, minúsculo, sem pontuação e sem as
    # palavras de ruído. Mantém a ordem das demais palavras.
    def key(name)
      tokens = I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, " ").split
      tokens.reject! { |t| NOISE_TOKENS.include?(t) }
      tokens.join(" ")
    end

    # Dado um conjunto de nomes (do mesmo grupo), propõe um nome canônico.
    # Regra: o mais frequente; empate desfeito pelo mais descritivo (mais longo).
    # `counts` opcional: hash { nome => frequência }.
    def canonical_for(names, counts: nil)
      uniq = names.map { |n| n.to_s.strip }.reject(&:blank?).uniq
      return nil if uniq.empty?

      uniq.max_by { |name| [counts ? counts[name].to_i : 0, name.length] }
    end
  end
end

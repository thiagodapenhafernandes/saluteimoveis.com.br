# frozen_string_literal: true

# Meta anual de captação por tipo (venda/locação). Histórica por ano.
# Usada pelo dashboard para calcular progresso contra a meta.
class CaptacaoGoal < ApplicationRecord
  enum kind: { venda: 0, locacao: 1 }, _prefix: true

  validates :year, presence: true, uniqueness: { scope: :kind }
  validates :target, numericality: { greater_than: 0 }

  scope :for_year, ->(y) { where(year: y) }

  def self.current_target(year:, kind:)
    find_by(year: year, kind: kind)&.target.to_i
  end

  def self.current_foco(year:, kind:)
    find_by(year: year, kind: kind)
  end
end

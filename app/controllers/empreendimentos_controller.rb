class EmpreendimentosController < ApplicationController
  def index
    @page_name = 'empreendimentos'
    
    # Base scope: only 'Empreendimento' type
    @empreendimentos = Habitation.empreendimentos_publicos.order(nome_empreendimento: :asc)

    # Filter by search term if present
    if params[:q].present?
      term = "%#{params[:q].downcase}%"
      @empreendimentos = @empreendimentos.where("unaccent(nome_empreendimento) ILIKE unaccent(?)", term)
    end

    # Pagination
    @empreendimentos = @empreendimentos.paginate(page: params[:page], per_page: 20)

    # Calculate unit counts for the current page to avoid N+1 on the whole table
    # We can do a group count query for all habitations that match these development codes
    development_codes = @empreendimentos.map(&:codigo).compact
    
    @unit_counts = Habitation.where.not(codigo_empreendimento: nil)
                             .where(codigo_empreendimento: development_codes)
                             .group(:codigo_empreendimento)
                             .count
  end

  def search
    term = params[:q]
    return render json: [] if term.blank?

    # Autocomplete search
    results = Habitation.empreendimentos_publicos
                        .where("unaccent(nome_empreendimento) ILIKE unaccent(?)", "%#{term}%")
                        .limit(10)
                        .pluck(:nome_empreendimento, :codigo)
                        .map { |name, code| { label: name, value: name } } # value is name for search param

    render json: results
  end
end

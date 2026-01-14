class Admin::HabitationsController < Admin::BaseController
  before_action :set_habitation, only: [:edit, :update, :destroy]

  before_action :load_autocomplete_data, only: [:new, :edit, :create, :update]

  def index
    @q = params[:q]
    @status = params[:status]
    @categoria = params[:categoria]

    # Sorting
    @sort_column = sort_column
    @sort_direction = sort_direction
    
    @habitations = Habitation.order(@sort_column => @sort_direction)
    
    @habitations = @habitations.where("codigo ILIKE :q OR titulo_anuncio ILIKE :q", q: "%#{@q}%") if @q.present?
    @habitations = @habitations.where(status: @status) if @status.present?
    @habitations = @habitations.where(categoria: @categoria) if @categoria.present?

    @habitations = @habitations.paginate(page: params[:page], per_page: 20)
    @page_title = "Gerenciar Imóveis"
  end

  def new
    @habitation = Habitation.new
    @page_title = "Novo Imóvel"
  end

  def create
    @habitation = Habitation.new(habitation_params)

    if @habitation.save
      redirect_to admin_habitations_path, notice: "Imóvel criado com sucesso."
    else
      load_autocomplete_data
      render :new
    end
  end


  def edit
    @page_title = "Editar Imóvel: #{@habitation.codigo}"
  end

  def update
    if @habitation.update(habitation_params)
      redirect_to admin_habitations_path, notice: "Imóvel atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habitation.destroy
    redirect_to admin_habitations_path, notice: "Imóvel excluído com sucesso."
  end

  def sync
    @habitation = Habitation.find(params[:id])
    result = SyncPropertyService.new(@habitation.codigo).perform

    if result[:success]
      redirect_to edit_admin_habitation_path(@habitation), notice: "Imóvel sincronizado com o Vista com sucesso!"
    else
      redirect_to edit_admin_habitation_path(@habitation), alert: "Erro na sincronização: #{result[:error]}"
    end
  end

  private

  def sort_column
    Habitation.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
  helper_method :sort_column, :sort_direction

  def set_habitation
    @habitation = Habitation.find(params[:id])
  end

  def load_autocomplete_data
    @categories = Habitation.distinct.pluck(:categoria).compact.sort
    @cities = Habitation.distinct.pluck(:cidade).compact.sort
    @neighborhoods = Habitation.distinct.pluck(:bairro).compact.sort
    @constructors = Habitation.distinct.pluck(:construtora).compact.sort
    @badges = Habitation.distinct.pluck(:caracteristica_unica).compact.sort
  end

  def habitation_params
    params.require(:habitation).permit(
      :codigo, :slug, :categoria, :status, :situacao, :tipo, :codigo_empreendimento, 
      :nome_empreendimento, :tipo_endereco, :endereco, :numero, :complemento, 
      :bairro, :cidade, :uf, :cep, :pais, :latitude, :longitude, 
      :dormitorios_qtd, :suites_qtd, :banheiros_qtd, :vagas_qtd, :elevadores_qtd, 
      :area_privativa_m2, :area_total_m2, :area_terreno_m2, :area_util_m2, 
      :valor_venda_formatted, :valor_locacao_formatted, :valor_condominio_formatted, :valor_iptu_formatted, :valor_por_m2_formatted, 
      :descricao_web, :descricao_interna, :titulo_anuncio, :observacoes, 
      :corretor_nome, :corretor_telefone, :corretor_email, :proprietario_codigo, 
      :exibir_no_site_flag, :destaque_web_flag, :lancamento_flag, :aceita_permuta_flag, 
      :aceita_financiamento_flag, :mobiliado_flag, :data_entrega, :status_vista, 
      :meta_title, :meta_description, :meta_keywords, 
      :piscina_flag, :lavabo_flag, :varanda_gourmet_flag, :bairro_comercial, :bloco, :lote, 
      :imediacoes, :banheiro_social_qtd, :decorado_flag, :aptos_andar, :aptos_edificio, 
      :garden_flag, :quadra_mar_flag, :sem_mobilia_flag, 
      :valor_venda_anterior_cents, :valor_total_aluguel_cents, :valor_promocional_formatted, 
      :construtora, :proprietario, :inscricao_imobiliaria, :descricao_empreendimento, 
      :caracteristica_unica, :categoria_grupo, :tour_virtual, 
      :terceira_avenida_flag, :arriba_flag, :avenida_brasil_flag, :bairro_fazenda_itajai_flag, 
      :balneario_picarras_flag, :barra_flag, :barra_norte_flag, :barra_sul_flag, 
      :cabecudas_flag, :camboriu_flag, :centro_flag, :estaleirinho_flag, 
      :frente_mar_avenida_atlantica_flag, :itajai_flag, :itapema_flag, :nacoes_flag, 
      :pioneiros_flag, :praia_brava_flag, :praia_dos_amores_flag, :vista_frente_mar_flag, 
      :festival_salute_flag, :exibir_no_site_salute_flag, :tem_placa_flag,
      videos: [], plantas: [], fotos_empreendimento: [], photos: [],
      ordered_photo_ids: [], imediacoes: [], meta_keywords: []
    )
  end
end

module Vista
  class ImportAgentsService
    require 'open-uri'

    VISTA_KEY  = ENV.fetch('VISTA_KEY')  { 'ea83a702a7669520304be011258289fd' }
    VISTA_HOST = ENV.fetch('VISTA_HOST') { 'http://saluteim20174-rest.vistahost.com.br' }
    LIST_PATH  = '/usuarios/listar'
    PAGE_SIZE  = 50

    def self.call
      new.call
    end

    def call
      puts "Iniciando importação de corretores do Vista..."
      
      page = 1
      total_processed = 0
      total_created = 0
      total_updated = 0

      loop do
        response = fetch_users(page)
        
        if response.blank? || response['status'].present? && response['status'].to_i >= 400
           puts "Erro ou fim da lista: #{response}"
           break
        end

        total_pages = response['paginas'].to_i
        users_data = response.except('total', 'paginas', 'pagina', 'quantidade')
        
        break if users_data.empty?

        users_data.each do |key, user_data|
          # Skip structural keys if any leak through, usually they are numeric strings "1", "2"
          next unless user_data.is_a?(Hash)
          
          process_user(user_data) ? total_created += 1 : total_updated += 1
          total_processed += 1
        end

        puts "Página #{page}/#{total_pages} processada."
        
        break if page >= total_pages
        page += 1
      end

      puts "Importação finalizada!"
      puts "Processados: #{total_processed} | Criados: #{total_created} | Atualizados: #{total_updated}"
    end

    private

    def fetch_users(page)
      # Fields verified via 'listarcampos' and manual testing
      fields = [
        'Codigo', 
        'Nomecompleto', 
        'E-mail', # Important: api uses hyphen
        'CRECI', 
        'Celular', 
        'Foto', 
        'Observacoes', 
        'Nascimento', 
        'Cidade', 
        'Sexo',
        'Inativo',
        'Atuaçãoemvenda',
        'Atuaçãoemlocação'
      ]
      
      query = {
        fields: fields,
        paginacao: {
          pagina: page,
          quantidade: PAGE_SIZE
        }
      }

      url = URI.join(VISTA_HOST, LIST_PATH).to_s
      params = {
        key: VISTA_KEY,
        pesquisa: query.to_json,
        showtotal: 1
      }

      response = RestClient.get(url, { params: params, accept: :json })
      JSON.parse(response.body)
    rescue => e
      puts "Erro na requisição: #{e.message}"
      {}
    end

    def process_user(data)
      return if data['Inativo'] == 'Sim'
      
      email = data['E-mail']
      return unless email.present?

      # Find by vista_id first to handle email changes, fallback to email
      user = AdminUser.find_by(vista_id: data['Codigo']) || AdminUser.find_or_initialize_by(email: email)
      is_new = user.new_record?

      user.vista_id = data['Codigo']
      user.name     = data['Nomecompleto'].presence || user.name
      user.creci    = data['CRECI']
      user.phone    = data['Celular']
      user.biography = data['Observacoes']
      user.city     = data['Cidade']
      
      # Assign Profile
      corretor_profile = Profile.find_by(name: 'Corretor')
      user.profile = corretor_profile if corretor_profile.present? && user.profile.nil?
      
      if data['Nascimento'].present? && data['Nascimento'] != '0000-00-00'
        user.birth_date = Date.parse(data['Nascimento']) rescue nil
      end

      # Map Acting Type
      venda = data['Atuaçãoemvenda'] == 'Sim'
      locacao = data['Atuaçãoemlocação'] == 'Sim'

      user.acting_type = if venda && locacao
                           :both
                         elsif venda
                           :sales
                         elsif locacao
                           :rentals
                         else
                           :both # Fallback if neither is set, though unlikely for active agents
                         end

      # Set default password for new users
      if is_new
        user.password = SecureRandom.hex(8) 
        # Optional: Send email with instructions? For now just setting it.
      end

      # Handle Avatar
      if data['Foto'].present?
        attach_avatar(user, data['Foto'])
      end

      if user.save
        print is_new ? "." : "*"
        is_new
      else
        puts "\nErro ao salvar #{email}: #{user.errors.full_messages.join(', ')}"
        false
      end
    end

    def attach_avatar(user, url)
      # Basic check to avoid re-downloading same image if logic existed, 
      # but ActiveStorage doesn't easily expose original URL. 
      # For now we update if it's there, or we could check filename hash.
      # To avoid heavy traffic, maybe skip if attached? 
      # But photos update. Let's rely on standard overwrite for now unless performance hit.
      
      return if user.avatar.attached? # Simple cache strategy: don't replace if exists for now, or maybe later check timestamps

      begin
        downloaded_image = URI.open(url)
        user.avatar.attach(io: downloaded_image, filename: "vista_avatar_#{user.vista_id}.jpg")
      rescue => e
        puts "\nErro ao baixar foto para #{user.email}: #{e.message}"
      end
    end
  end
end

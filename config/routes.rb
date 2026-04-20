Rails.application.routes.draw do
  devise_for :admin_users, path: 'admin', controllers: {
    sessions: 'admin/sessions',
    omniauth_callbacks: 'admin/omniauth_callbacks'
  }
  
  # Admin Panel
  namespace :admin do
    get 'admin_users/index'
    get 'admin_users/new'
    get 'admin_users/edit'
    get 'admin_users/show'
    resources :profiles
    resources :habitations do
      member do
        post :sync
      end
      collection do
        get :print
        get :export
      end
    end
    
    resources :attribute_options, only: [:index, :create, :update, :destroy]
    resources :proprietors do
      collection do
        get :print
        get :export
      end
    end

    root to: 'dashboard#index'
    
    resource :home_setting, only: [:edit, :update]
    resource :contact_setting, only: [:edit, :update]
    resource :layout_setting, only: [:show, :edit, :update]
    resource :footer_setting, only: [:edit, :update]
    resources :webhook_settings do
      post :test, on: :member
    end
    resources :seo_settings
    resources :banners
    resources :home_sections do
      member do
        patch :toggle_active
      end
      collection do
        patch :update_order
      end
      resources :home_section_items, only: [:new, :create, :edit, :update, :destroy]
    end
    resources :admin_users, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :habitations do
      post :sync, on: :member
      delete "purge_attachment/:association/:attachment_id", on: :member, action: :purge_attachment, as: :purge_attachment
    end
    resources :leads, only: [:index, :show, :update, :destroy]
    resources :distribution_rules do
      patch :toggle_active, on: :member
    end
    resources :meta_integrations, only: [:index] do
      collection do
        post :sync_pages
        post :sync_forms
        delete :disconnect
        get :list_forms
      end
    end
    resource :dwv_integrations, only: [:show, :update] do
      get :status
      post :test_connection
      post :sync_property
      post :sync_now
      post :sync_recent
      post :deactivate_removed
    end
    resource :loft_integrations, only: [:show, :update] do
      get :status
      post :test_connection
      post :sync_property
      post :sync_now
      post :sync_batch
      post :sync_images_now
    end
    resources :portal_integrations, only: [:index, :update], param: :portal do
      post :test_feed, on: :member
      get :preview_feed, on: :member
    end
    resources :landing_pages do
      get :preview, on: :collection
    end
  end
  # Root
  root 'home#index'
  
  # Home pages
  get 'sobre', to: 'home#sobre', as: :sobre
  get 'imobiliaria', to: 'home#sobre' # Alias para "Sobre Nós"
  get 'contato', to: 'home#contato', as: :contato
  
  # Corretores/Brokers
  get 'corretores', to: 'brokers#index', as: :brokers
  
  # Static pages
  get 'trabalhe-conosco', to: 'pages#trabalhe_conosco', as: :trabalhe_conosco
  get 'salute-parcerias', to: 'pages#parcerias', as: :parcerias
  get 'simulador-financiamento', to: 'pages#simulador', as: :simulador
  get 'politica-de-privacidade', to: 'pages#privacy_policy', as: :privacy_policy
  get 'termos-de-uso', to: 'pages#terms_of_use', as: :terms_of_use

  resources :empreendimentos, only: [:index] do
    collection do
      get :search
    end
  end
  get 'empreendimento/:id', to: 'habitations#show', as: :empreendimento_details
  get 'empreendimetos', to: redirect('/empreendimentos')
  get 'links-uteis', to: 'pages#links_uteis', as: :links_uteis
  get 'corporativos', to: 'pages#corporativos', as: :corporativos
  
  # Autocomplete
  get 'autocomplete/locations', to: 'autocomplete#locations'
  
  # Quick search by code
  get 'buscar-codigo', to: 'habitations#search_by_code', as: :search_by_code
  
  # Habitations - SEO friendly routes  
  resources :habitations, only: [:index, :show], path: 'imoveis' do
    member do
      post :schedule_visit
      post :share_link
    end
    collection do
      get :autocomplete
      post :search_by_code
    end
  end

  get 'imoveis-com-oportunidade', to: redirect('/imoveis?characteristics[]=opportunity')
  
  # Form submissions
  resources :contacts, only: [:create]
  post 'trabalhe-conosco/submit', to: 'pages#submit_trabalhe_conosco', as: :submit_trabalhe_conosco
  post 'salute-parcerias/submit', to: 'pages#submit_parcerias', as: :submit_parcerias
  # Alternative routes for SEO
  get 'imovel/:id', to: 'habitations#show', as: :property
  get 'venda', to: 'habitations#index', defaults: { transaction_type: 'venda' }, as: :venda
  get 'venda/:category', to: 'habitations#index', defaults: { transaction_type: 'venda' }, as: :venda_category
  get 'aluguel', to: 'habitations#index', defaults: { transaction_type: 'aluguel' }, as: :aluguel
  get 'aluguel/:category', to: 'habitations#index', defaults: { transaction_type: 'aluguel' }, as: :aluguel_category
  
  # API namespace (opcional, para futuras APIs)
  namespace :api do
    namespace :v1 do
      resources :habitations, only: [:index, :show]
      get 'search', to: 'search#index'
      get 'autocomplete', to: 'search#autocomplete'
    end
  end
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Public Leads creation
  resources :leads, only: [:create]

  # Mission Control for Jobs
  mount MissionControl::Jobs::Engine => "/jobs"

  # Webhooks
  namespace :webhooks do
    post "meta", to: "meta#receive_leads"
    get "meta", to: "meta#receive_leads"
    post "portals/:portal/events", to: "portals#events", as: :portal_events
  end

  namespace :integrations do
    namespace :portals do
      get ":portal/:token", to: "feeds#show", as: :feed_token
      get ":portal/feed", to: "feeds#show", as: :feed
    end
  end

  # Catch-all route for public landing pages
  get '/:slug', to: 'landing_pages#show', constraints: lambda { |req|
    LandingPage.exists?(slug: req.params[:slug])
  }, as: :public_landing_page
end

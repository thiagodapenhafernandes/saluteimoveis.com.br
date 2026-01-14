# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_12_012254) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.integer "role", default: 0, null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "banners", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "link_url"
    t.string "link_text"
    t.integer "position"
    t.boolean "active"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "positions", default: [], array: true
  end

  create_table "contact_settings", force: :cascade do |t|
    t.string "whatsapp_primary"
    t.string "whatsapp_secondary"
    t.string "phone"
    t.string "email_primary"
    t.string "email_commercial"
    t.text "address"
    t.text "business_hours"
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "youtube_url"
    t.string "linkedin_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "featured_properties_views", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "footer_links", force: :cascade do |t|
    t.string "label"
    t.string "url"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "footer_setting_id", null: false
    t.index ["footer_setting_id"], name: "index_footer_links_on_footer_setting_id"
  end

  create_table "footer_settings", force: :cascade do |t|
    t.string "about_title"
    t.text "about_text"
    t.string "links_title"
    t.string "stores_title"
    t.string "contact_title"
    t.string "social_title"
    t.string "whatsapp"
    t.string "email"
    t.string "copyright_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "footer_social_links", force: :cascade do |t|
    t.string "platform"
    t.string "url"
    t.boolean "enabled"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "footer_setting_id", null: false
    t.index ["footer_setting_id"], name: "index_footer_social_links_on_footer_setting_id"
  end

  create_table "footer_stores", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "zip_code"
    t.string "creci"
    t.string "phone"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "footer_setting_id", null: false
    t.index ["footer_setting_id"], name: "index_footer_stores_on_footer_setting_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "habitations", force: :cascade do |t|
    t.string "codigo", null: false
    t.string "slug"
    t.string "categoria"
    t.string "status"
    t.string "situacao"
    t.string "tipo"
    t.string "codigo_empreendimento"
    t.string "nome_empreendimento"
    t.string "tipo_endereco"
    t.string "endereco"
    t.string "numero"
    t.string "complemento"
    t.string "bairro"
    t.string "cidade"
    t.string "uf", limit: 2
    t.string "cep", limit: 10
    t.string "pais", default: "Brasil"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.integer "dormitorios_qtd", default: 0
    t.integer "suites_qtd", default: 0
    t.integer "banheiros_qtd", default: 0
    t.integer "vagas_qtd", default: 0
    t.integer "elevadores_qtd", default: 0
    t.decimal "area_privativa_m2", precision: 10, scale: 2
    t.decimal "area_total_m2", precision: 10, scale: 2
    t.decimal "area_terreno_m2", precision: 10, scale: 2
    t.decimal "area_util_m2", precision: 10, scale: 2
    t.bigint "valor_venda_cents"
    t.bigint "valor_locacao_cents"
    t.bigint "valor_condominio_cents"
    t.bigint "valor_iptu_cents"
    t.bigint "valor_por_m2_cents"
    t.jsonb "caracteristicas", default: {}
    t.jsonb "infra_estrutura", default: {}
    t.jsonb "destaque_localizacao", default: {}
    t.jsonb "pictures", default: []
    t.jsonb "videos", default: []
    t.jsonb "plantas", default: []
    t.text "descricao_web"
    t.text "descricao_interna"
    t.string "titulo_anuncio"
    t.text "observacoes"
    t.string "corretor_nome"
    t.string "corretor_telefone"
    t.string "corretor_email"
    t.string "proprietario_codigo"
    t.boolean "exibir_no_site_flag", default: false
    t.boolean "destaque_web_flag", default: false
    t.boolean "lancamento_flag", default: false
    t.boolean "aceita_permuta_flag", default: false
    t.boolean "aceita_financiamento_flag", default: false
    t.boolean "mobiliado_flag", default: false
    t.datetime "data_atualizacao_crm"
    t.datetime "data_cadastro_crm"
    t.string "status_vista"
    t.string "meta_title"
    t.text "meta_description"
    t.string "meta_keywords"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "piscina_flag", default: false
    t.boolean "lavabo_flag", default: false
    t.boolean "varanda_gourmet_flag", default: false
    t.string "bairro_comercial"
    t.string "bloco"
    t.string "lote"
    t.text "imediacoes"
    t.integer "banheiro_social_qtd"
    t.boolean "decorado_flag"
    t.integer "aptos_andar"
    t.integer "aptos_edificio"
    t.boolean "garden_flag"
    t.boolean "quadra_mar_flag"
    t.boolean "sem_mobilia_flag"
    t.integer "valor_venda_anterior_cents"
    t.integer "valor_total_aluguel_cents"
    t.integer "valor_promocional_cents"
    t.string "construtora"
    t.string "proprietario"
    t.string "inscricao_imobiliaria"
    t.text "descricao_empreendimento"
    t.text "caracteristica_unica"
    t.boolean "terceira_avenida_flag"
    t.boolean "arriba_flag"
    t.boolean "avenida_brasil_flag"
    t.boolean "bairro_fazenda_itajai_flag"
    t.boolean "balneario_picarras_flag"
    t.boolean "barra_flag"
    t.boolean "barra_norte_flag"
    t.boolean "barra_sul_flag"
    t.boolean "cabecudas_flag"
    t.boolean "camboriu_flag"
    t.boolean "centro_flag"
    t.boolean "estaleirinho_flag"
    t.boolean "frente_mar_avenida_atlantica_flag"
    t.boolean "itajai_flag"
    t.boolean "itapema_flag"
    t.boolean "nacoes_flag"
    t.boolean "pioneiros_flag"
    t.boolean "praia_brava_flag"
    t.boolean "praia_dos_amores_flag"
    t.boolean "vista_frente_mar_flag"
    t.boolean "festival_salute_flag"
    t.boolean "exibir_no_site_salute_flag"
    t.string "categoria_grupo"
    t.date "data_entrega"
    t.string "tour_virtual"
    t.jsonb "fotos_empreendimento"
    t.string "codigo_corretor"
    t.string "captador_account_id"
    t.string "agenciador"
    t.string "codigo_dwv"
    t.string "imovel_dwv"
    t.boolean "tem_placa_flag"
    t.jsonb "photo_ids_order", default: []
    t.datetime "last_sync_at"
    t.string "last_sync_status"
    t.text "last_sync_message"
    t.index ["area_total_m2"], name: "index_habitations_on_area_total_m2"
    t.index ["caracteristicas"], name: "index_habitations_on_caracteristicas", using: :gin
    t.index ["categoria", "status"], name: "idx_habitations_categoria_status"
    t.index ["centro_flag"], name: "index_habitations_on_centro_flag"
    t.index ["cidade", "bairro", "status"], name: "idx_habitations_localizacao_status"
    t.index ["codigo"], name: "index_habitations_on_codigo", unique: true
    t.index ["codigo_empreendimento"], name: "index_habitations_on_codigo_empreendimento"
    t.index ["created_at"], name: "index_habitations_on_created_at"
    t.index ["data_atualizacao_crm"], name: "index_habitations_on_data_atualizacao_crm"
    t.index ["destaque_localizacao"], name: "index_habitations_on_destaque_localizacao", using: :gin
    t.index ["destaque_web_flag"], name: "index_habitations_on_destaque_web_flag"
    t.index ["dormitorios_qtd"], name: "index_habitations_on_dormitorios_qtd"
    t.index ["exibir_no_site_flag", "status"], name: "idx_habitations_exibir_status"
    t.index ["frente_mar_avenida_atlantica_flag"], name: "index_habitations_on_frente_mar_avenida_atlantica_flag"
    t.index ["infra_estrutura"], name: "index_habitations_on_infra_estrutura", using: :gin
    t.index ["lancamento_flag"], name: "index_habitations_on_lancamento_flag"
    t.index ["latitude", "longitude"], name: "idx_habitations_geolocation"
    t.index ["lavabo_flag"], name: "index_habitations_on_lavabo_flag"
    t.index ["pictures"], name: "index_habitations_on_pictures", using: :gin
    t.index ["piscina_flag"], name: "index_habitations_on_piscina_flag"
    t.index ["praia_brava_flag"], name: "index_habitations_on_praia_brava_flag"
    t.index ["quadra_mar_flag"], name: "index_habitations_on_quadra_mar_flag"
    t.index ["slug"], name: "index_habitations_on_slug", unique: true
    t.index ["status", "categoria", "cidade"], name: "idx_habitations_status_categoria_cidade"
    t.index ["updated_at"], name: "index_habitations_on_updated_at"
    t.index ["vagas_qtd"], name: "index_habitations_on_vagas_qtd"
    t.index ["valor_locacao_cents"], name: "index_habitations_on_valor_locacao_cents"
    t.index ["valor_venda_cents", "status"], name: "idx_habitations_venda_status"
    t.index ["valor_venda_cents"], name: "index_habitations_on_valor_venda_cents"
  end

  create_table "home_section_items", force: :cascade do |t|
    t.bigint "home_section_id", null: false
    t.string "title"
    t.text "description"
    t.boolean "active"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["home_section_id"], name: "index_home_section_items_on_home_section_id"
  end

  create_table "home_sections", force: :cascade do |t|
    t.integer "section_type"
    t.string "title"
    t.text "subtitle"
    t.boolean "active"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_position", default: 0
  end

  create_table "home_settings", force: :cascade do |t|
    t.text "hero_title"
    t.text "hero_subtitle"
    t.text "cta_title"
    t.text "cta_subtitle"
    t.boolean "services_active"
    t.boolean "why_choose_active"
    t.boolean "cta_contact_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hero_cta_text"
    t.string "hero_cta_link"
    t.decimal "overlay_opacity"
    t.string "overlay_color"
    t.string "hero_button_color"
    t.string "hero_button_text_color"
  end

  create_table "landing_pages", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.jsonb "filter_params", default: {}
    t.string "meta_title"
    t.text "meta_description"
    t.text "content"
    t.boolean "active"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "layout_settings", force: :cascade do |t|
    t.string "primary_color"
    t.string "secondary_color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "site_name"
    t.string "accent_color"
  end

  create_table "leads", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.integer "property_id"
    t.string "source_url"
    t.string "lead_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.text "notes"
  end

  create_table "property_pages", force: :cascade do |t|
    t.string "title", null: false
    t.string "meta_title"
    t.text "meta_description"
    t.string "slug", null: false
    t.jsonb "filter_params", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_property_pages_on_slug", unique: true
  end

  create_table "seo_settings", force: :cascade do |t|
    t.string "page_name"
    t.string "meta_title"
    t.text "meta_description"
    t.text "meta_keywords"
    t.string "og_image"
    t.string "canonical_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "webhook_settings", force: :cascade do |t|
    t.string "webhook_url"
    t.boolean "enabled"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_webhook_url"
    t.boolean "lead_capture_enabled"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "footer_links", "footer_settings"
  add_foreign_key "footer_social_links", "footer_settings"
  add_foreign_key "footer_stores", "footer_settings"
  add_foreign_key "home_section_items", "home_sections"
end

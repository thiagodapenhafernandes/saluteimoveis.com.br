# 🚀 Setup do Salute Imóveis V3

## Como Executar o Setup

O script `setup_new_project.sh` foi criado e está pronto para executar. Ele vai criar **tudo** automaticamente!

### Executar Setup Completo

```bash
cd /Users/thiagofernandes/workspaces/salute-imoveis-v2
./setup_new_project.sh
```

⏱️ **Tempo estimado**: 2-3 minutos

---

## O que o Script Faz

### ✅ Tarefas Automatizadas

1. **Cria o projeto Rails** com todas as configurações otimizadas
2. **Configura Gemfile** com todas gems necessárias:
   - Performance: Redis, Sidekiq, cache
   - SEO: meta-tags, friendly_id, sitemap
   - API: rest-client, httparty
   - Deploy: mina, puma-daemon
   - Pagination: will_paginate
3. **Instala todas as gems** automaticamente
4. **Cria arquivos .env** (example e development)
5. **Configura database.yml** para PostgreSQL
6. **Configura Puma** (3 workers em produção)
7. **Setup Redis** (cache, Sidekiq, sessions)
8. **Cria estrutura de diretórios** otimizada:
   ```
   app/
   ├── models/concerns/habitation/
   ├── services/cache/
   ├── services/seo/
   └── queries/
   ```
9. **Inicializa Git** com commit inicial
10. **Cria databases** (development e test)

---

## Estrutura do Projeto Criado

```
salute-imoveis-v3/
├── app/
│   ├── models/
│   │   └── concerns/
│   │       └── habitation/          # Concerns do modelo
│   ├── controllers/
│   │   └── concerns/                # Controller concerns
│   ├── services/
│   │   ├── cache/                   # Cache management
│   │   └── seo/                     # SEO services
│   └── queries/                     # Query objects
│
├── config/
│   ├── database.yml                 # PostgreSQL config
│   ├── puma.rb                      # Puma server
│   └── initializers/
│       ├── redis.rb                 # Redis setup
│       ├── cache.rb                 # Cache config
│       └── sidekiq.rb               # Sidekiq config
│
├── .env                             # Environment variables
├── .env.example                     # Template
└── Gemfile                          # All gems configured
```

---

## Após o Setup

### 1️⃣ Editar Configurações

**Edite o arquivo `.env`:**

```bash
cd salute-imoveis-v3
nano .env
```

**Configure suas credenciais:**
- Database (se necessário)
- Redis URL (se remoto)
- Vista Soft API keys
- AWS/CDN credentials

### 2️⃣ Iniciar o Servidor

```bash
# Development mode
rails server

# Ou com porta específica
rails s -p 3000
```

Acesse: http://localhost:3000

### 3️⃣ Sidekiq (Background Jobs)

```bash
# Em outro terminal
bundle exec sidekiq
```

### 4️⃣ Console Rails

```bash
rails console
# ou
rails c
```

---

## Próximos Passos de Desenvolvimento

### Fase 1: Modelo Habitation

Vou criar para você:

1. **Migration completa** do Habitation
2. **Modelo com concerns**:
   - `PriceFormatting`
   - `SearchScopes`
   - `CacheableMethods`
   - `SeoHelpers`
3. **Índices otimizados** para performance

### Fase 2: Vista Soft Integration

1. **Importacao via Thor** (`bundle exec thor builder_fields --force`)
2. **Acompanhamento de progresso** (`bundle exec rake 'vista:progress[UUID]'`)

### Fase 3: Controllers & Views

1. **HabitationsController** com cache
2. **HomeController** otimizado
3. **Views** com lazy loading
4. **Partials** reutilizáveis

### Fase 4: SEO & Performance

1. **Meta tags dinâmicas**
2. **Structured data** (Schema.org)
3. **Sitemap** generator
4. **Image optimization**

### Fase 5: Deploy

1. **Mina configuration**
2. **Deploy scripts**
3. **Production optimization**

---

## Comandos Úteis

### Database

```bash
# Criar databases
rails db:create

# Rodar migrations
rails db:migrate

# Seed data
rails db:seed

# Rollback
rails db:rollback

# Reset
rails db:reset
```

### Assets

```bash
# Precompile (produção)
rails assets:precompile

# Clean
rails assets:clean
```

### Cache

```bash
# Limpar cache
rails cache:clear

# Ver estatísticas (após criar rake task)
rails cache:stats
```

### Sidekiq

```bash
# Iniciar
bundle exec sidekiq

# Com configuração customizada
bundle exec sidekiq -C config/sidekiq.yml
```

### Performance Testing

```bash
# Benchmark (após criar)
rails performance:benchmark

# Memory profiling
rails performance:memory
```

---

## Gems Instaladas

### Core
- **rails** 7.1.2
- **pg** (PostgreSQL)
- **puma** (servidor)
- **redis** (cache/jobs)

### Performance
- **sidekiq** - Background jobs
- **rack-attack** - Rate limiting
- **dalli** - Memcached
- **bootsnap** - Boot optimization

### Frontend
- **bootstrap** 5.3
- **stimulus-rails**
- **turbo-rails**
- **sassc-rails**
- **importmap-rails**

### SEO & Images
- **meta-tags** - Meta tags dinâmicas
- **friendly_id** - URLs amigáveis
- **sitemap_generator** - Sitemap XML
- **carrierwave** - Upload de imagens
- **mini_magick** - Image processing

### API & External
- **rest-client** - HTTP requests
- **httparty** - API client
- **dotenv-rails** - Environment vars

### Utilities
- **will_paginate** - Paginação
- **brazilian-rails** - Locales PT-BR
- **device_detector** - Device detection

### Development
- **pry** - Debug console
- **bullet** - N+1 detection
- **annotate** - Schema comments
- **mina** - Deploy

---

## Verificação do Setup

### ✅ Checklist

Após executar o script, verifique:

- [ ] Projeto criado em `/Users/thiagofernandes/workspaces/salute-imoveis-v3`
- [ ] Gems instaladas (`bundle list`)
- [ ] Database criado (`rails db:version`)
- [ ] Redis conectando (`redis-cli ping`)
- [ ] Servidor inicia (`rails s`)
- [ ] Git inicializado (`.git/` existe)

### 🔍 Testes Rápidos

```bash
cd salute-imoveis-v3

# 1. Verificar gems
bundle list | grep redis
bundle list | grep sidekiq
bundle list | grep will_paginate

# 2. Verificar database
rails db:version

# 3. Verificar Redis (se estiver rodando)
rails runner "puts $redis.ping"

# 4. Iniciar servidor (Ctrl+C para parar)
rails s
```

---

## Troubleshooting

### ❌ Erro: PostgreSQL não está rodando

```bash
# Mac (Homebrew)
brew services start postgresql@15

# Linux
sudo systemctl start postgresql
```

### ❌ Erro: Redis não está rodando

```bash
# Mac (Homebrew)
brew services start redis

# Linux
sudo systemctl start redis
```

### ❌ Erro: Bundle install falhou

```bash
# Limpar e reinstalar
rm -rf vendor/bundle
rm Gemfile.lock
bundle install
```

### ❌ Erro: Database connection

Verifique o `.env`:
```env
DB_USERNAME=postgres
DB_PASSWORD=sua_senha
DB_HOST=localhost
```

---

## Pronto! 🎉

Seu projeto está configurado e pronto para desenvolvimento!

**O que temos agora:**
- ✅ Projeto Rails otimizado
- ✅ Todas gems instaladas
- ✅ Redis e Sidekiq configurados
- ✅ Database setup
- ✅ Estrutura de diretórios
- ✅ Git inicializado

**Próximo passo:**
Criar o modelo Habitation e começar a migração de dados! 🚀

source "https://rubygems.org"
ruby "3.2.3"

# Core Rails
gem "rails", "~> 7.1.2"
gem "pg", "~> 1.5"
gem "puma", "~> 6.4"
gem "puma-daemon", require: false

# Assets & Frontend
gem "sprockets-rails"
gem "importmap-rails"
gem "stimulus-rails"
gem "turbo-rails"
gem "sassc-rails"
gem "terser"
gem "image_processing", "~> 1.12"
gem "bootstrap", "~> 5.3"

# Environment & Configuration
gem "dotenv-rails"
gem "meta-tags"

# Database & Background Jobs
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.0"
gem "connection_pool"

# Pagination
gem "will_paginate", "~> 4.0"
gem "will_paginate-bootstrap-style"

# API & External Services
gem "rest-client"
gem "httparty"

# Performance & Caching
gem "rack-cors"
gem "rack-attack"
gem "dalli"

# SEO & Images
gem "sitemap_generator"
gem "friendly_id"
gem "mini_magick"
gem "carrierwave", "~> 3.0"
gem "fog-aws"

# Authentication
gem "bcrypt", "~> 3.1.7"

# Utilities
gem "brazilian-rails"
gem "device_detector"

# Required
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "pry"
  gem "pry-rails"
  gem "bullet"
end

group :development do
  gem "web-console"
  gem "mina"
  gem "annotate"
end

group :production do
  gem "lograge"
end

ruby '3.4.6'
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

## Authentication, authorization & friends
# gem 'cancancan'
# gem 'pundit'
gem 'bcrypt', '~> 3.1.20'
gem 'devise'
# gem 'omniauth-google-oauth2'
# gem 'omniauth-rails_csrf_protection'

## Rails
gem 'bootsnap', require: false
gem 'puma', '~> 6.0'
gem 'rails', '~> 8.1'
# gem 'route_translator', '~> 14.1', '>= 14.1.1' # TODO: Temporarily disabled due to Rails 8.1 incompatibility

## Front-end and Asset Pipeline
gem 'avo'
gem 'cssbundling-rails', '~> 1.2'
gem 'draper'
gem 'jbuilder'
gem 'jsbundling-rails'
# gem 'rack-cache', '~> 1.14'
gem 'rack-cors'
gem 'sprockets-rails'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'view_component', '~> 4.1'
gem 'will_paginate'
# gem 'will_paginate-bootstrap-style'
gem 'tailwindcss-rails', '~> 4.2'
gem 'tailwindcss-ruby', '~> 4.1'

## Database and Storage
# gem 'activerecord-import', '~> 1.5'
# gem 'audited', '~> 5.3', '>= 5.3.3'
# gem 'google-cloud-storage', require: false
gem 'nilify_blanks'
gem 'pg', '~> 1.1'
# gem 'pg_query'
# gem 'pg_search'
gem 'prosopite', '~> 1.4'
# gem "kredis"
gem 'redis', '~> 5.0'
# gem 'scenic'
# gem 'image_processing', '~> 1.2'
# gem 'with_advisory_lock', '~> 5.1'

## Background Job Processing
gem 'sidekiq'
gem 'sidekiq-scheduler'

## Working with data
gem 'active_interaction'
# gem 'csv'
gem 'dry-struct'
gem 'friendly_id', '~> 5.5'
# gem 'json-schema'
# gem 'jwt'
gem 'nokogiri'
gem 'oj'
# gem 'panko_serializer'
# gem 'rswag-api'
# gem 'rswag-ui'
# gem 'user_agent_parser'

## Document tools
# gem 'diffy'
# gem 'kramdown'
# gem 'pdf-reader'

## Third-Party Integrations
# gem 'aws-sdk-s3', '~> 1.148'
gem 'googleauth'
# gem 'google-cloud-bigquery', '~> 1.35', require: false
# gem 'google-cloud-vision'
gem 'httparty'
gem 'mailjet'
gem 'octokit', '~> 9.0'
gem 'posthog-ruby'
gem 'ruby-openai', '~> 7', '>= 7.3'

# Sentry
gem 'sentry-rails'
gem 'sentry-ruby'

## Development and Test
group :development, :test do
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'pry-rails'
  gem 'rspec-rails'
  gem 'shoulda-matchers', '~> 6.0'
  # gem 'rswag-specs'
end

group :development do
  gem 'letter_opener'
  gem 'letter_opener_web'
  # gem 'rack-mini-profiler'
  gem 'web-console'
  # gem "spring"
end

group :test do
  gem 'capybara'
  gem 'database_cleaner', '~> 2.0', '>= 2.0.2'
  gem 'webdrivers'
  gem 'webmock'
end

## Miscellaneous
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Load environment variables from .env file
# gem 'dotenv', groups: %i[development test]

# frozen_string_literal: true

Migflow::Engine.routes.draw do
  root to: "application#index"

  get "assets/migflow/app.js",  to: "static#app_js"
  get "assets/migflow/app.css", to: "static#app_css"

  namespace :api do
    resources :migrations, only: %i[index show]
    get "diff", to: "diff#show"
  end
end

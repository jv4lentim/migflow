# frozen_string_literal: true

Migflow::Engine.routes.draw do
  root to: "application#index"

  namespace :api do
    resources :migrations, only: [:index, :show]
    get "diff",     to: "diff#show"
    get "warnings", to: "warnings#index"
  end
end

# frozen_string_literal: true

Migflow::Engine.routes.draw do
  root to: "application#index"

  namespace :api do
    resources :migrations, only: %i[index show]
    get "diff", to: "diff#show"
  end
end

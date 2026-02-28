# frozen_string_literal: true

module Migrail
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :null_session

    def index
      render "migrail/application/index"
    end

    private

    def migrations_path
      Migrail.configuration.resolved_migrations_path
    end

    def schema_path
      Migrail.configuration.resolved_schema_path
    end

    def render_json(status: :ok, **data)
      render json: data, status: status
    end

    def render_error(message, status: :unprocessable_entity)
      render json: { error: message }, status: status
    end
  end
end

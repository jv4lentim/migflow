# frozen_string_literal: true

module Migflow
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :null_session

    def index
      render "migflow/application/index"
    end

    private

    def migrations_path
      Migflow.configuration.resolved_migrations_path
    end

    def schema_path
      Migflow.configuration.resolved_schema_path
    end

    def render_json(status: :ok, **data)
      render json: data, status: status
    end

    def render_error(message, status: :unprocessable_entity)
      render json: { error: message }, status: status
    end
  end
end

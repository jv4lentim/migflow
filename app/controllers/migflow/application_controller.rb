# frozen_string_literal: true

module Migflow
  class ApplicationController < Migflow.configuration.parent_controller.constantize
    layout false
    protect_from_forgery with: :null_session
    before_action :run_user_before_action

    def index
      render "migflow/application/index"
    end

    private

    def run_user_before_action
      hook = Migflow.configuration.authentication_hook
      instance_exec(&hook) if hook
    end

    def request_authentication
      redir = Migflow.configuration.unauthenticated_redirect
      if redir
        session[:return_to_after_authenticating] = request.url
        redirect_to instance_exec(&redir)
      else
        super
      end
    end

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

    def serialize_schema_patches(from_tables:, to_tables:, changed_tables: nil)
      {
        schema_patch: Services::SchemaPatchBuilder.call(
          from_tables: from_tables,
          to_tables: to_tables,
          changed_tables: changed_tables,
          include_unchanged: false
        ),
        schema_patch_full: Services::SchemaPatchBuilder.call(
          from_tables: from_tables,
          to_tables: to_tables,
          include_unchanged: true
        )
      }
    end
  end
end

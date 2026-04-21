# frozen_string_literal: true

module Migflow
  class Engine < ::Rails::Engine
    isolate_namespace Migflow

    initializer "migflow.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets")
        app.config.assets.precompile += %w[migflow/app.js migflow/app.css]
      end
    end
  end
end

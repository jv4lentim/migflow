# frozen_string_literal: true

module Migrail
  class Engine < ::Rails::Engine
    isolate_namespace Migrail

    initializer "migrail.assets" do |app|
      app.config.assets.paths << root.join("app/assets")
      app.config.assets.precompile += %w[migrail/app.js migrail/app.css]
    end
  end
end

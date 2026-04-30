# frozen_string_literal: true

module Migflow
  class StaticController < ActionController::Base
    layout false

    def app_js
      send_file Migflow::Engine.root.join("app/assets/migflow/app.js"),
                type: "application/javascript",
                disposition: "inline"
    end

    def app_css
      send_file Migflow::Engine.root.join("app/assets/migflow/app.css"),
                type: "text/css",
                disposition: "inline"
    end
  end
end

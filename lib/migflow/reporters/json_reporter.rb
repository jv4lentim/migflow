# frozen_string_literal: true

require "json"

module Migflow
  module Reporters
    class JsonReporter
      def render(report)
        JSON.pretty_generate(report)
      end
    end
  end
end

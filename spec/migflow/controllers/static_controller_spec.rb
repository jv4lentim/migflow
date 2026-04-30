# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require_relative "../../../app/controllers/migflow/static_controller"

RSpec.describe Migflow::StaticController do
  subject(:controller) { described_class.new }

  let(:engine_root) { Pathname.new(File.expand_path("../../..", __dir__)) }

  before do
    stub_const("Migflow::Engine", double(root: engine_root))
    allow(controller).to receive(:send_file)
  end

  describe "#app_js" do
    it "sends app.js with the correct path and MIME type" do
      controller.app_js

      expect(controller).to have_received(:send_file)
        .with(engine_root.join("app/assets/migflow/app.js"),
              type: "application/javascript",
              disposition: "inline")
    end
  end

  describe "#app_css" do
    it "sends app.css with the correct path and MIME type" do
      controller.app_css

      expect(controller).to have_received(:send_file)
        .with(engine_root.join("app/assets/migflow/app.css"),
              type: "text/css",
              disposition: "inline")
    end
  end
end

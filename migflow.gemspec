# frozen_string_literal: true

require_relative "lib/migflow/version"

Gem::Specification.new do |spec|
  spec.name        = "migflow"
  spec.version     = Migflow::VERSION
  spec.authors     = ["Joao Victor Valentim"]
  spec.email       = ["joaovictorvalentim@gmail.com"]
  spec.summary     = "Visual migration history and audit panel for Rails apps"
  spec.description = "Mount /migflow in any Rails app to visualize, diff and audit your migration history"
  spec.homepage    = "https://github.com/joaovalentim/migflow"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile frontend/])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
end

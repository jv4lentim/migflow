# frozen_string_literal: true

require "migflow/services/report_generator"
require "migflow/reporters"

namespace :migflow do
  desc "Analyze migrations and output a report. Options: FORMAT=markdown|json, FAIL_ON=<level|score>, OUTPUT=<path>"
  task report: :environment do
    format    = ENV.fetch("FORMAT", "markdown")
    fail_on   = ENV.fetch("FAIL_ON", nil)
    output    = ENV.fetch("OUTPUT", nil)

    report = Migflow::Services::ReportGenerator.new.call(
      migrations_path: Migflow.configuration.resolved_migrations_path
    )
    rendered = Migflow::Reporters.for(format).render(report)

    if output
      File.write(output, rendered)
      $stdout.puts "Report written to #{output}"
    else
      $stdout.puts rendered
    end

    threshold = Migflow::Reporters.resolve_threshold(fail_on)
    if threshold && report[:summary][:highest_risk_score] >= threshold
      warn "migflow: gate failed — highest risk score #{report[:summary][:highest_risk_score]} >= #{threshold}"
      exit 1
    end
  end
end

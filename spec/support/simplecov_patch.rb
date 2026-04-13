# frozen_string_literal: true

require 'simplecov'

# Monkeypatch SimpleCov to avoid NoMethodError on Ruby 4.0.2 when branch data is nil
module SimpleCov
  class SourceFile
    def build_branches
      coverage_branch_data = coverage_data.fetch("branches", {})
      return [] if coverage_branch_data.nil?

      branches = coverage_branch_data.flat_map do |condition, coverage_branches|
        build_branches_from(condition, coverage_branches)
      end

      process_skipped_branches(branches)
    end
  end
end

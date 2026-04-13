# frozen_string_literal: true

module JiraMocks
  # A class that implements the methods we need to mock from JIRA-ruby
  # but in a way that satisfies RSpec instance_double.
  class Issue
    def key; end
    def summary; end
    def created; end
    def issuetype; end
    def changelog; end
    def resolutiondate; end
  end

  class Issuetype
    def name; end
  end
end

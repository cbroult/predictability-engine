# frozen_string_literal: true

require_relative 'docs_refresher'

namespace :docs do
  desc 'Refresh <!-- run: cmd --> / <!-- end --> blocks in documentation/*.md with live command output'
  task :refresh do
    Dir['documentation/*.md'].each do |path|
      original = File.read(path)
      updated  = DocsRefresher.new(original).refresh
      if updated == original
        puts "  unchanged  #{path}"
      else
        File.write(path, updated)
        puts "  refreshed  #{path}"
      end
    end
  end
end

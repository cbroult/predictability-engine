# frozen_string_literal: true

require 'jira-ruby'
require 'optparse'
require_relative '../lib/predictability_engine/config'

# This script seeds a Jira project with test data to verify the predictability engine's
# integration with real Jira instances.
#
# Usage:
#   JIRA_SITE=https://your-domain.atlassian.net \
#   JIRA_EMAIL=your-email@example.com \
#   JIRA_API_TOKEN=your-token \
#   ruby scripts/jira_seeder.rb --project TESTPROJ --count 5
#

class JiraSeeder
  def initialize(options)
    @config = PredictabilityEngine::Config.jira(ENV['JIRA_PROFILE'])
    @project_key = options[:project] || @config[:project]
    @count = options[:count] || 5
    @client = build_client
  end

  def run
    puts "Seeding Jira project #{@project_key} with #{@count} issues..."
    
    # 1. Verify project exists
    project = @client.Project.find(@project_key)
    puts "Found project: #{project.name}"

    # 2. Create issues
    @count.times do |i|
      summary = "Test Issue #{Time.now.to_i} - #{i}"
      issue = @client.Issue.build
      issue.save({
        'fields' => {
          'project' => { 'key' => @project_key },
          'summary' => summary,
          'issuetype' => { 'name' => 'Story' }
        }
      })
      puts "Created issue: #{issue.key}"

      # 3. Transition some issues to simulate workflow
      # 60% in progress, 20% done, 20% to do
      case i % 5
      when 0, 1, 2
        transition_to(issue, 'In Progress')
      when 3
        transition_to(issue, 'In Progress')
        transition_to(issue, 'Done')
      end
    end
    
    puts "Seeding completed successfully."
  end

  def cleanup
    puts "Cleaning up issues in project #{@project_key}..."
    issues = @client.Issue.jql("project = #{@project_key}")
    issues.each do |issue|
      puts "  Deleting #{issue.key}"
      issue.delete
    end
    puts "Cleanup completed."
  end

  private

  def build_client
    options = {
      username: @config[:email],
      password: @config[:token],
      site: @config[:site],
      context_path: '',
      auth_type: :basic
    }
    ::JIRA::Client.new(options)
  end

  def transition_to(issue, status_name)
    transitions = @client.Transition.all(issue: issue)
    target = transitions.find { |t| t.name.downcase.include?(status_name.downcase) }
    
    if target
      transition = issue.transitions.build
      transition.save!('transition' => { 'id' => target.id })
      puts "  Transitioned #{issue.key} to #{status_name}"
    else
      puts "  Warning: Could not find transition to '#{status_name}' for #{issue.key}"
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: jira_seeder.rb [options]"
  opts.on("-p", "--project KEY", "Jira project key") { |v| options[:project] = v }
  opts.on("-c", "--count N", Integer, "Number of issues to create") { |v| options[:count] = v }
  opts.on("--cleanup", "Delete all issues in the project before seeding") { options[:cleanup] = true }
end.parse!

if options[:project].nil?
  puts "Error: Project key is required."
  exit 1
end

begin
  seeder = JiraSeeder.new(options)
  seeder.cleanup if options[:cleanup]
  seeder.run
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
  exit 1
end

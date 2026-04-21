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
    @config = PredictabilityEngine::Config.jira(ENV.fetch('JIRA_PROFILE', nil))
    @project_key = options[:project] || @config[:project]
    @count = options[:count] || 5
    @client = build_client
  end

  def run
    puts "Seeding Jira project #{@project_key} with #{@count} tickets..."

    # 1. Verify project exists
    project = @client.Project.find(@project_key)
    puts "Found project: #{project.name}"

    # 2. Create tickets
    @count.times do |i|
      summary = "Test Issue #{Time.now.to_i} - #{i}"
      ticket = @client.Issue.build
      ticket.save({ 'fields' => { 'project' => { 'key' => @project_key },
                                  'summary' => summary,
                                  'issuetype' => { 'name' => 'Story' } } })
      puts "Created ticket: #{ticket.key}"

      # 3. Transition some tickets to simulate workflow
      # 60% in progress, 20% done, 20% to do
      case i % 5
      when 0, 1, 2
        transition_to(ticket, 'In Progress')
      when 3
        transition_to(ticket, 'In Progress')
        transition_to(ticket, 'Done')
      end
    end

    puts 'Seeding completed successfully.'
  end

  def cleanup
    puts "Cleaning up tickets in project #{@project_key}..."
    tickets = @client.Issue.jql("project = #{@project_key}")
    tickets.each do |ticket|
      puts "  Deleting #{ticket.key}"
      ticket.delete
    end
    puts 'Cleanup completed.'
  end

  private

  def build_client
    PredictabilityEngine::Config.jira_client(ENV.fetch('JIRA_PROFILE', nil))
  end

  def transition_to(ticket, status_name)
    transitions = @client.Transition.all(issue: ticket)
    target = transitions.find { |t| t.name.downcase.include?(status_name.downcase) }

    if target
      transition = ticket.transitions.build
      transition.save!('transition' => { 'id' => target.id })
      puts "  Transitioned #{ticket.key} to #{status_name}"
    else
      puts "  Warning: Could not find transition to '#{status_name}' for #{ticket.key}"
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: jira_seeder.rb [options]'
  opts.on('-p', '--project KEY', 'Jira project key') { |v| options[:project] = v }
  opts.on('-c', '--count N', Integer, 'Number of tickets to create') { |v| options[:count] = v }
  opts.on('--cleanup', 'Delete all tickets in the project before seeding') { options[:cleanup] = true }
end.parse!

if options[:project].nil?
  puts 'Error: Project key is required.'
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

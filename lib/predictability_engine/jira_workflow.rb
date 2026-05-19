# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module PredictabilityEngine
  # Editable mapping of Jira workflow statuses → arrival/departure roles.
  # Extracted from Jira's status catalogue, persisted to YAML, and consumed
  # by DataSources::Jira to drive start_date / end_date selection.
  class JiraWorkflow
    DEFAULT_PATH_TEMPLATE = '~/.config/jira/%s.workflow.yml'
    CATEGORY_ROLE_DEFAULTS = { 'in progress' => 'arrival', 'done' => 'departure' }.freeze
    ROLES = %w[arrival departure].freeze

    attr_reader :profile, :project, :statuses

    def initialize(profile: nil, project: nil, statuses: [])
      @profile = profile
      @project = project
      @statuses = statuses.map { |s| self.class.normalize_status(s) }
    end

    def self.default_path(profile_name)
      File.expand_path(format(DEFAULT_PATH_TEMPLATE, profile_name))
    end

    def self.load(path)
      return nil unless path && File.exist?(path)

      raw = Config.load_yaml_file(path) || {}
      new(profile: raw['profile'], project: raw['project'], statuses: raw['statuses'] || [])
    end

    def self.extract(profile_name, client: nil)
      client ||= Config.jira_client(profile_name)
      project = Config.jira(profile_name)[:project]
      statuses = fetch_statuses(client).map { |s| seed_role(s) }
      new(profile: profile_name, project: project, statuses: statuses)
    end

    # Refresh an existing config against a fresh Jira fetch:
    # - statuses the user already annotated keep their role
    # - brand-new statuses are added with the seeded default role
    # - statuses that disappeared from Jira are dropped
    def refresh(fresh)
      existing_roles = @statuses.to_h { |s| [s[:name], s[:role]] }
      @statuses = fresh.statuses.map do |s|
        s.merge(role: existing_roles.key?(s[:name]) ? existing_roles[s[:name]] : s[:role])
      end
      @profile ||= fresh.profile
      @project ||= fresh.project
      self
    end

    def self.merge(configs)
      merged = {}
      configs.each do |cfg|
        cfg.statuses.each { |s| merge_status(merged, s) }
      end
      new(statuses: merged.values)
    end

    def self.normalize_status(hash)
      h = hash.transform_keys(&:to_s)
      role = h['role'].to_s.empty? ? nil : h['role'].to_s
      { name: h['name'], category: h['category'], role: role }
    end

    def write(path)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      File.write(path, to_hash.to_yaml)
      path
    end

    def to_hash
      {
        'profile' => @profile,
        'project' => @project,
        'statuses' => @statuses.map { |s| s.transform_keys(&:to_s) }
      }.compact
    end

    def arrival_names
      names_for('arrival')
    end

    def departure_names
      names_for('departure')
    end

    def self.fetch_statuses(client)
      entries = client.Status.all.map { |status| status_entry(status) }
      entries.uniq { |s| s[:name] }
    rescue StandardError => e
      PredictabilityEngine.logger.warn { "Failed to fetch Jira statuses: #{e.message}" }
      []
    end

    def self.status_entry(status)
      category = begin
        status.statusCategory['name'].to_s.downcase
      rescue StandardError
        nil
      end
      { name: status.name, category: category }
    end

    def self.seed_role(status)
      status.merge(role: CATEGORY_ROLE_DEFAULTS[status[:category]])
    end

    def self.merge_status(target, status)
      existing = target[status[:name]]
      if existing
        warn_conflict(existing, status) if existing[:role] && status[:role] && existing[:role] != status[:role]
        existing[:role] ||= status[:role]
        existing[:category] ||= status[:category]
      else
        target[status[:name]] = status.dup
      end
    end

    def self.warn_conflict(existing, incoming)
      PredictabilityEngine.logger.warn do
        "Workflow merge conflict for '#{existing[:name]}': role " \
          "#{existing[:role]} vs #{incoming[:role]} (kept #{existing[:role]})"
      end
    end

    private_class_method :fetch_statuses, :status_entry, :seed_role, :merge_status, :warn_conflict

    private

    def names_for(role)
      @statuses.select { |s| s[:role] == role }.map { |s| s[:name] }
    end
  end
end

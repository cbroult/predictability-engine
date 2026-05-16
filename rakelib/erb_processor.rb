# frozen_string_literal: true

require 'erb'

# Processes *.erb template files, exposing project version variables so that
# version numbers are specified only once (in .ruby-version) and propagated
# automatically to all derived files.
#
# Also updates marker sections in README.md (<!-- MARKER_START --> / <!-- MARKER_END -->)
# using content from matching documentation/*.md.erb templates.
class ErbProcessor
  RUBY_VERSION_FILE = '.ruby-version'
  README_PATH = 'README.md'

  README_SECTIONS = {
    'RUBY_PREREQUISITES' => 'documentation/ruby_prerequisites.md.erb'
  }.freeze

  def self.ruby_version
    File.read(RUBY_VERSION_FILE).strip.split('-').last
  end

  def self.process_all
    process_erb_files
    update_readme_sections
  end

  def self.process_erb_files
    Dir['{**/*,**/.*}.erb'].reject { |f| f.start_with?('vendor/') }.each do |template_path|
      next if README_SECTIONS.value?(template_path)

      output_path = template_path.delete_suffix('.erb')
      new_content = new(template_path).render
      write_if_changed(output_path, new_content)
    end
  end

  def self.update_readme_sections
    return unless File.exist?(README_PATH)

    readme = File.read(README_PATH)
    README_SECTIONS.each do |marker, template_path|
      next unless File.exist?(template_path)

      rendered = new(template_path).render.strip
      readme = replace_marker_section(readme, marker, rendered)
    end
    write_if_changed(README_PATH, readme)
  end

  def self.replace_marker_section(content, marker, replacement)
    start_tag = "<!-- #{marker}_START -->"
    end_tag   = "<!-- #{marker}_END -->"
    content.gsub(/#{Regexp.escape(start_tag)}.*?#{Regexp.escape(end_tag)}/m,
                 "#{start_tag}\n#{replacement}\n#{end_tag}")
  end

  def self.write_if_changed(path, new_content)
    if File.exist?(path) && File.read(path) == new_content
      puts "  unchanged  #{path}"
    else
      File.write(path, new_content)
      puts "  generated  #{path}"
    end
  end

  private_class_method :process_erb_files, :update_readme_sections,
                       :replace_marker_section, :write_if_changed

  def initialize(template_path)
    @template_path = template_path
  end

  def render
    ruby_version = self.class.ruby_version
    ERB.new(File.read(@template_path), trim_mode: '-').result(binding)
  end
end

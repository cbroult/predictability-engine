# frozen_string_literal: true

RSpec.shared_context 'with mocked today' do
  around do |example|
    old_mock_today = ENV.fetch('MOCK_TODAY', nil)
    ENV['MOCK_TODAY'] = today.to_s
    example.run
    ENV['MOCK_TODAY'] = old_mock_today
  end
end

# Redirects all SemanticLogger output to a StringIO buffer for each example.
# setup_logging only removes its own previously registered appenders (not this
# test appender), so CLI#initialize will not disturb the capture buffer.
# Usage:
#   include_context 'with captured logger'
#   it { expect(log_output.string).to include('saved') }
RSpec.shared_context 'with captured logger' do
  # Flush SemanticLogger's async background thread before reading so assertions
  # don't race against messages still queued in the appender worker.
  let(:log_output) do
    StringIO.new.tap do |io|
      io.define_singleton_method(:string) do
        SemanticLogger.flush
        super()
      end
    end
  end

  around do |example|
    orig_appenders = SemanticLogger.appenders.dup
    orig_level = SemanticLogger.default_level
    SemanticLogger.appenders.dup.each { |a| SemanticLogger.remove_appender(a) }
    SemanticLogger.add_appender(io: log_output, formatter: :default)
    example.run
    SemanticLogger.flush
    SemanticLogger.appenders.dup.each { |a| SemanticLogger.remove_appender(a) }
    orig_appenders.each { |a| SemanticLogger.add_appender(a) }
    SemanticLogger.default_level = orig_level
  end
end

RSpec.shared_context 'with sample work items' do
  let(:items) do
    [
      build_item('1', '2024-01-01', '2024-01-05'),
      build_item('2', '2024-01-02', '2024-01-08')
    ]
  end

  def build_item(item_id, start_date, end_date = nil)
    PredictabilityEngine::Models::WorkItem.new(item_id: item_id, start_date: start_date, end_date: end_date)
  end

  def mock_item(completed: true, end_date: nil, cycle_time: nil, start_date: nil)
    instance_double(PredictabilityEngine::Models::WorkItem,
                    completed?: completed, end_date: end_date,
                    cycle_time: cycle_time, start_date: start_date)
  end
end

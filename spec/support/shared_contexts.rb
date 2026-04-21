# frozen_string_literal: true

# Redirects PredictabilityEngine logger output to a StringIO buffer for each
# example. Avoids the `output` matcher + singleton-reset dance; the logger is
# bound to the buffer before subject creation so Thor's initialize doesn't
# accidentally capture real $stdout.
#
# Usage:
#   include_context 'with captured logger'
#   it { expect(log_output).to include('saved') }
RSpec.shared_context 'with mocked today' do
  around do |example|
    old_mock_today = ENV.fetch('MOCK_TODAY', nil)
    ENV['MOCK_TODAY'] = today.to_s
    example.run
    ENV['MOCK_TODAY'] = old_mock_today
  end
end

RSpec.shared_context 'with captured logger' do
  let(:log_output) { StringIO.new }

  before do
    PredictabilityEngine::Logger.instance_variable_set(:@instance, nil)
    inst = PredictabilityEngine::Logger.instance
    buf_logger = Logger.new(log_output)
    buf_logger.formatter = proc { |_sev, _dt, _prog, msg| "#{msg}\n" }
    inst.instance_variable_set(:@console_logger, buf_logger)
  end

  after do
    PredictabilityEngine::Logger.instance_variable_set(:@instance, nil)
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

# frozen_string_literal: true

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

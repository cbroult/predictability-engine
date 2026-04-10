# frozen_string_literal: true

module PredictabilityEngine
  module Agents
    class Assistant
      attr_reader :llm, :assistant, :tools

      def initialize(data_manager)
        # Using OpenAI as default. Requires OPENAI_API_KEY in .env
        @llm = Langchain::LLM::OpenAI.new(api_key: ENV.fetch('OPENAI_API_KEY', nil))
        @tools = [PredictabilityEngine::Agents::Tools.new(data_manager)]

        @assistant = Langchain::Assistant.new(
          llm: @llm,
          tools: @tools,
          instructions: "You are an expert in Actionable Agile Metrics and Daniel Vacanti's predictability methods.
                        Your job is to answer 'When will it be done?' questions based on historical data.
                        Always explain the statistical confidence (p85) to the user.
                        You can also analyze Cumulative Flow Diagrams for anomalies like growing WIP."
        )
      end

      def ask(question)
        @assistant.add_message(question)
        @assistant.run
      end
    end
  end
end

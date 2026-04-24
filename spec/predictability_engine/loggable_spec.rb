# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Lint/ConstantDefinitionInBlock, Lint/EmptyClass, RSpec/LeakyConstantDeclaration, RSpec/SpecFilePathFormat
# These tests must define real classes/modules so the TracePoint(:end) auto-inclusion fires;
# stub_const would bypass the code path we want to verify.
RSpec.describe SemanticLogger::Loggable do
  it 'is included in every class/module defined under PredictabilityEngine::' do
    module PredictabilityEngine
      class DummyFoo; end

      module DummyNested
        class Bar; end
      end
    end

    expect(PredictabilityEngine::DummyFoo.ancestors).to include(described_class)
    expect(PredictabilityEngine::DummyNested.ancestors).to include(described_class)
    expect(PredictabilityEngine::DummyNested::Bar.ancestors).to include(described_class)
  end

  it 'exposes a named SemanticLogger on both instance and class' do
    module PredictabilityEngine
      class DummyBaz; end
    end
    expect(PredictabilityEngine::DummyBaz.logger).to be_a(SemanticLogger::Logger)
    expect(PredictabilityEngine::DummyBaz.logger.name).to eq('PredictabilityEngine::DummyBaz')
    expect(PredictabilityEngine::DummyBaz.new.logger.name).to eq('PredictabilityEngine::DummyBaz')
  end

  it 'does not pollute Object' do
    expect(Object.ancestors).not_to include(described_class)
  end

  it 'does not inject into modules outside the PredictabilityEngine:: namespace' do
    module SomeOtherNamespace
      class Outsider; end
    end
    expect(SomeOtherNamespace::Outsider.ancestors).not_to include(described_class)
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, Lint/EmptyClass, RSpec/LeakyConstantDeclaration, RSpec/SpecFilePathFormat

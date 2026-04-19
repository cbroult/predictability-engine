# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Lint/ConstantDefinitionInBlock, Lint/EmptyClass, RSpec/LeakyConstantDeclaration
# These tests must define real classes/modules so the TracePoint(:end) auto-inclusion fires;
# stub_const would bypass the code path we want to verify.
RSpec.describe PredictabilityEngine::Loggable do
  it 'is included in every class/module defined under PredictabilityEngine::' do
    module PredictabilityEngine
      class DummyFoo; end

      module DummyNested
        class Bar; end
      end
    end

    expect(PredictabilityEngine::DummyFoo.include?(described_class)).to be true
    expect(PredictabilityEngine::DummyNested.include?(described_class)).to be true
    expect(PredictabilityEngine::DummyNested::Bar.include?(described_class)).to be true
  end

  it 'exposes logger on both instance and class' do
    module PredictabilityEngine
      class DummyBaz; end
    end
    expect(PredictabilityEngine::DummyBaz.logger).to equal(PredictabilityEngine.logger)
    expect(PredictabilityEngine::DummyBaz.new.logger).to equal(PredictabilityEngine.logger)
  end

  it 'does not pollute Object' do
    expect(Object.include?(described_class)).to be false
  end

  it 'does not inject into modules outside the PredictabilityEngine:: namespace' do
    module SomeOtherNamespace
      class Outsider; end
    end
    expect(SomeOtherNamespace::Outsider.include?(described_class)).to be false
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, Lint/EmptyClass, RSpec/LeakyConstantDeclaration

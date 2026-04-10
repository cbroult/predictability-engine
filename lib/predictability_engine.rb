# frozen_string_literal: true

require 'zeitwerk'
require 'csv'
require 'dotenv'
require 'json'
require 'langchain'

Dotenv.load

loader = Zeitwerk::Loader.for_gem
loader.setup

module PredictabilityEngine
  class Error < StandardError; end
end

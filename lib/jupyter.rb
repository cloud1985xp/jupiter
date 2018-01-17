require 'ruby-jmeter'
require 'active_support'
require 'active_support/core_ext'
require 'yaml'
require 'aws-sdk'
require "jupyter/config"
require "jupyter/errors"
require "jupyter/version"

module Jupyter
  DEFAULT_THREADS_COUNT = 1.freeze
  DEFAULT_THREADS_RAMPUP = 60.freeze
  DEFAULT_CONTROLLER_LOOPS = 1.freeze
  DEFAULT_DURATION = 60000.freeze

  class << self
    def env=(val)
      @env = val
    end

    def env
      @env || 'development'
    end

    def config
      @config ||= Jupyter::Config.new(env)
    end

    def options
      @options || {}
    end

    def options=(v)
      @options = v
    end

    def settings
      @settings ||= begin
        OpenStruct.new(
          threads: {
            count: options.fetch(:threads, DEFAULT_THREADS_COUNT),
            rampup: options.fetch(:rampup, DEFAULT_THREADS_RAMPUP),
            loop: 1,
            duration: options.fetch(:duration, DEFAULT_DURATION)
          },
          loop_controller: { count: options.fetch(:loop, DEFAULT_CONTROLLER_LOOPS) }
        )
      end
    end

    # For JMeter DSL
    def threads_settings
      settings.threads.dup
    end

    def loop_controller_settings
      settings.loop_controller.dup
    end
  end
end

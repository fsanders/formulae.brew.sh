# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2018, Sebastian Staudt

require 'main_import'
require 'tap_import'

if defined? ::NewRelic
  def task_with_tracing(*options)
    caller_method = options.first
    caller_method = caller_method.keys.first if caller_method.is_a? Hash

    task(*options) do
      include NewRelic::Agent::Instrumentation::ControllerInstrumentation

      perform_action_with_newrelic_trace name: caller_method.to_s,
                                         category: :task, force: true do
        yield
      end
    end
  end
else
  class << self
    alias task_with_tracing task
  end
end

if defined? Rollbar
  def rollbar_rescued
    yield
  rescue
    Rollbar.error $!
  end
else
  def rollbar_rescued
    yield
  end
end

namespace :braumeister do

  Rails.logger = Logger.new STDOUT

  task :select_repo, [:repo] => :update_main do
    @core = Repository.core.extend TapImport
  end

  desc 'Completely regenerates one or all repositories and their formulae'
  task_with_tracing :regenerate, [:repo] => :select_repo do
    @core.regenerate!
  end

  desc 'Regenerates the history of one or all repositories'
  task_with_tracing :regenerate_history, [:repo] => :select_repo do
    @core.generate_history!
  end

  desc 'Pulls the latest changes from one or all repositories'
  task_with_tracing :update, [:repo] => :select_repo do
    rollbar_rescued do
      last_sha = @core.refresh
      @core.generate_history last_sha
    end
  end

  desc 'Pulls the latest changes from the main repository'
  task_with_tracing :update_main => :environment do
    rollbar_rescued do
      repo = Repository.main.extend MainImport
      repo.update_status
    end
  end

  desc 'Updates metadata from one or all tap repositories'
  task_with_tracing :update_metadata do
    rollbar_rescued do
      CORE.update_metadata
    end
  end

end

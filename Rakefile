# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

namespace :spec do
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.rspec_opts = %w[--format progress]
  end

  desc 'Run integration specs'
  task :integration do
    sh 'bundle', 'exec', 'bacon', 'spec/integration.rb', '-q'
  end

  namespace :integration do
    desc 'Update integration spec fixtures'
    task :update do
      rm_rf 'spec/integration/tmp'
      sh('bin/rake', 'spec:integration') {}
      # Copy the files to the files produced by the specs to the after folders
      FileList['spec/integration/tmp/*/transformed'].each do |source|
        walk_dir = lambda do |d|
          Dir.each_child(d) do |c|
            child = File.join(d, c)
            walk_dir[child] if File.directory?(child)
          end
          Dir.delete(d) if Dir.empty?(d)
        end
        walk_dir[source]

        name = source.match(%r{tmp/([^/]+)/transformed$})[1]
        destination = "spec/integration/#{name}/after"
        rm_rf destination
        mv source, destination
      end
    end
  end
end

desc 'Run all specs'
# TODO: add back integration once we can fix its dep on rules_ios
task spec: %w[spec:unit]

RuboCop::RakeTask.new(:rubocop)

task default: %i[spec rubocop]

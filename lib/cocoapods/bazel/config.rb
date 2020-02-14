# frozen_string_literal: true

module Pod
  module Bazel
    class Config
      PLUGIN_KEY = 'cocoapods-bazel'
      private_constant :PLUGIN_KEY
      DEFAULTS = {
        rules: {
          'apple_framework' => { load: '@build_bazel_rules_ios//rules:framework.bzl', rule: 'apple_framework' }.freeze,
          'ios_application' => { load: '@build_bazel_rules_ios//rules:app.bzl', rule: 'ios_application' }.freeze,
          'ios_unit_test' => { load: '@build_bazel_rules_ios//rules:test.bzl', rule: 'ios_unit_test' }.freeze
        }.freeze,
        overrides: {}.freeze,
        buildifier: true
      }.with_indifferent_access.freeze
      private_constant :DEFAULTS

      attr_reader :to_h

      def self.enabled_in_podfile?(podfile)
        podfile.plugins.key?(PLUGIN_KEY)
      end

      def self.from_podfile(podfile)
        return unless enabled_in_podfile?(podfile)

        from_podfile_options(podfile.plugins[PLUGIN_KEY])
      end

      def self.from_podfile_options(options)
        new(DEFAULTS.merge(options) do |_key, old_val, new_val|
          case old_val
          when Hash
            old_val.merge(new_val) # intentionally only 1 level deep of merging
          else
            new_val
          end
        end)
      end

      def initialize(to_h)
        @to_h = to_h
      end

      def buildifier
        to_h[:buildifier]
      end

      def load_for(macro:)
        to_h.dig('rules', macro) || raise("no rule configured for #{macro}")
      end
    end
  end
end

# frozen_string_literal: true

module Pod
  module Bazel
    class Config
      PLUGIN_KEY = 'cocoapods-bazel'
      private_constant :PLUGIN_KEY
      DEFAULTS = {
        rules: {
          'apple_framework' => { load: '@rules_ios//:framework.bzl', rule: 'apple_framework' }.freeze,
          'ios_application' => { load: '@rules_ios//:app.bzl', rule: 'ios_application' }.freeze,
          'ios_unit_test' => { load: '@rules_ios//:test.bzl', rule: 'ios_unit_test' }.freeze
        }.freeze,
        overrides: {}.freeze
      }.with_indifferent_access.freeze
      private_constant :DEFAULTS

      attr_reader :to_h

      # plugin('cocoapods-bazelizer',
      #        rules: {
      #          'apple_framework' => { load: '@rules_square//:framework.bzl', rule: 'sq_apple_framework' },
      #          'ios_application' => { load: '@rules_square//:app.bzl', rule: 'sq_ios_application' },
      #          'ios_unit_test'   => { load: '@rules_square//:test.bzl', rule: 'sq_ios_unit_test' },
      #        },
      #       overrides: {
      #         'Protobuf' => {
      #           'defines' => ['GPB_...=1']
      #         }
      #       })

      def self.enabled_in_podfile?(podfile)
        podfile.plugins.key?(PLUGIN_KEY)
      end

      def self.from_podfile(podfile)
        return unless enabled_in_podfile?(podfile)

        from_podfile_options(podfile.plugins[PLUGIN_KEY])
      end

      def self.from_podfile_options(options)
        new(DEFAULTS.merge(options) do |_key, old_val, new_val|
          old_val.merge(new_val) # intentionally only 1 level deep of merging
        end)
      end

      def initialize(to_h)
        @to_h = to_h
      end

      def load_for(macro:)
        to_h.dig('rules', macro) || raise("no rule configured for #{macro}")
      end
    end
  end
end

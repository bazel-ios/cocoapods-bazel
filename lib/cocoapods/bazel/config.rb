# frozen_string_literal: true

module Pod
  module Bazel
    class Config
      PLUGIN_KEY = 'cocoapods-bazel'
      EXPERIMENTAL_FEATURES = [
        # When enabled cocoapods-bazel will add one additional config_setting for the 'deps' attribute only
        # containing both 'debug' and 'release' dependencies.
        #
        # In other works when this flag is active cocoapods-bazel will continue to create these:
        #
        # - //Pods/cocoapods-bazel:debug
        # - //Pods/cocoapods-bazel:release
        #
        # and generate the same 'select()' statements for all attributes but 'deps'.
        #
        # Additionaly these new config_setting values will be created:
        #
        # - //Pods/cocoapods-bazel:deps_debug
        # - //Pods/cocoapods-bazel:deps_release
        # - //Pods/cocoapods-bazel:deps_debug_and_release
        #
        # and used only in the 'deps' attribute.
        #
        # This effectively decouple 'deps' from the other attributes from a configuration perspective and allow one to build
        # with different combinations of these settings. One example of a use case is generating release builds with 'debug' dependencies
        # available so debug-only features can be used to inspect/validate behaviour in a release build (some call these "dogfood" builds).
        #
        # From a conceptual perspective this will generate BUILD files with "all" states and allow one to use bazel features to 'select()' the desired ones.
        # This intentionally breaks the contract with the .podspec specification since cocoapods does not have the concept of 'select()'-ing configurations.
        #
        # Still in the context of the use case above ('dogfood' builds), without this experimental feature one would have to
        # change the configurations in the .podspec file from:
        #   `s.dependency 'Foo', configurations: %w[Debug]`
        # to:
        #   `s.dependency 'Foo', configurations: %w[Debug Release]`
        # and re-run cocoapods-bazel to generate the desired type of build and then re-run it again to go back to the previous state.
        #
        # This might be ok for some teams but it prevents others that are interested in using cocoapods-bazel to migrate to Bazel and eventually stop
        # depending on cocoapods. If the generated BUILD files don't contain "all" states and a 'pod install' is always required it's not trivial how to eventually treat the
        # BUILD files as source of truth.
        :experimental_deps_debug_and_release
      ].freeze
      private_constant :PLUGIN_KEY
      DEFAULTS = {
        rules: {
          'apple_framework' => { load: '@build_bazel_rules_ios//rules:framework.bzl', rule: 'apple_framework' }.freeze,
          'ios_application' => { load: '@build_bazel_rules_ios//rules:app.bzl', rule: 'ios_application' }.freeze,
          'ios_unit_test' => { load: '@build_bazel_rules_ios//rules:test.bzl', rule: 'ios_unit_test' }.freeze
        }.freeze,
        overrides: {}.freeze,
        buildifier: true,
        default_xcconfigs: {}.freeze,
        features: {
          experimental_deps_debug_and_release: false
        }
      }.with_indifferent_access.freeze

      private_constant :DEFAULTS

      attr_reader :to_h

      def self.enabled_in_podfile?(podfile)
        podfile.plugins.key?(PLUGIN_KEY)
      end

      def self.from_podfile(podfile)
        return unless enabled_in_podfile?(podfile)

        plugin_config = podfile.plugins[PLUGIN_KEY]

        features = plugin_config[:features] || {}
        features.each do |key|
          raise "Unrecognized feature: #{key} in Podfile. Available options: #{FEATURES}" unless FEATURES.include?(key)
        end

        from_podfile_options(plugin_config)
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

      def default_xcconfigs
        to_h[:default_xcconfigs]
      end

      def experimental_deps_debug_and_release
        to_h[:experimental_deps_debug_and_release]
      end
    end
  end
end

# frozen_string_literal: true

module Pod
  module Bazel
    module XCConfigResolver
      module_function

      def resolved_build_setting_value(setting, settings:)
        return unless (value = settings[setting])

        sub_prefix = ->(s) { s.sub(%r{\A:/}, '') }
        resolved = resolve_string_with_build_settings(value, settings: settings)
        if Pod::Target::BuildSettings::PLURAL_SETTINGS.include?(setting)
          resolved.shellsplit.reject(&:empty?).map(&sub_prefix)
        else
          sub_prefix[resolved]
        end
      end

      def resolve_string_with_build_settings(string, settings:)
        return string unless string =~ /\$(?:\{([_a-zA-Z0-0]+?)\}|\(([_a-zA-Z0-0]+?)\))/

        match, key = Regexp.last_match.values_at(0, 1, 2).compact
        sub = settings.fetch(key, '')
        resolve_string_with_build_settings(string.gsub(match, sub), settings: settings)
      end

      UNRESOLVED_SETTINGS = [
        'CONFIGURATION', # not needed, only used to help resolve other settings that may use it in substitutions
        'HEADER_SEARCH_PATHS', # serialized into copts, handled natively by Xcode instead of via xcspecs
        'OTHER_CFLAGS', # serialized separately as objc_copts
        'OTHER_SWIFT_FLAGS', # serialized separately as swift_copts
        'PODS_TARGET_SRCROOT', # not needed, used to help resolve file references relative to the current package
        'SDKROOT', # not needed since the SDKROOT gets propagated via the apple configuration transition
        'SRCROOT', # not needed, used to help resolve file references relative to the current workspace
        'SWIFT_VERSION', # serialized separately as swift_version
        'USER_HEADER_SEARCH_PATHS' # serialized into copts, handled natively by Xcode instead of via xcspecs
      ].freeze
      private_constant :UNRESOLVED_SETTINGS

      def resolve_xcconfig(xcconfig, default_xcconfigs: [])
        matching_defaults = default_xcconfigs.select do |_, config|
          (config.keys - xcconfig.keys).empty?
        end

        xcconfig.each_key { |k| xcconfig[k] = resolved_build_setting_value(k, settings: xcconfig) }
        xcconfig.delete_if do |k, v|
          UNRESOLVED_SETTINGS.include?(k) || v.empty?
        end

        unless matching_defaults.empty?
          transformed = matching_defaults.map do |name, default_config|
            [name, xcconfig.reject do |k, v|
              v == default_config[k]
            end]
          end
          name, xcconfig = transformed.min_by { |(_, config)| config.size }
        end

        [name, xcconfig]
      end
    end
  end
end

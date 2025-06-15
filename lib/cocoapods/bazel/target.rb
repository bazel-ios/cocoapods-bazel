# frozen_string_literal: true

require 'set'

require_relative 'xcconfig_resolver'

module Pod
  module Bazel
    class Target
      class RuleArgs
        attr_reader :kwargs

        def initialize
          @kwargs = {}

          yield self if block_given?
        end

        def add(name, value, defaults: nil)
          return self if defaults&.include?(value)

          raise 'Duplicate' if kwargs.key?(name)

          kwargs[name] = value

          self
        end
      end

      include XCConfigResolver

      attr_reader :installer, :pod_target, :file_accessors, :non_library_spec, :label, :package, :default_xcconfigs, :resolved_xconfig_by_config, :relative_sandbox_root

      # rubocop:disable Style/AccessModifierDeclarations
      private :installer, :pod_target, :file_accessors, :non_library_spec, :label, :package, :default_xcconfigs, :resolved_xconfig_by_config, :relative_sandbox_root
      # rubocop:enable Style/AccessModifierDeclarations

      def initialize(installer, pod_target, non_library_spec = nil, default_xcconfigs = {}, experimental_deps_debug_and_release = false,
                     xcframework_excluded_platforms = [], enable_add_testonly = false)
        @installer = installer
        @pod_target = pod_target
        @file_accessors = non_library_spec ? pod_target.file_accessors.select { |fa| fa.spec == non_library_spec } : pod_target.file_accessors.select { |fa| fa.spec.library_specification? }
        @non_library_spec = non_library_spec
        @label = (non_library_spec ? pod_target.non_library_spec_label(non_library_spec) : pod_target.label)
        @package_dir = installer.sandbox.pod_dir(pod_target.pod_name)
        @package = installer.sandbox.pod_dir(pod_target.pod_name).relative_path_from(installer.config.installation_root).to_s
        @default_xcconfigs = default_xcconfigs
        @resolved_xconfig_by_config = {}
        @experimental_deps_debug_and_release = experimental_deps_debug_and_release
        @xcframework_excluded_platforms = xcframework_excluded_platforms
        @enable_add_testonly = enable_add_testonly
        @relative_sandbox_root = installer.sandbox.root.relative_path_from(installer.config.installation_root).to_s
      end

      def bazel_label(relative_to: nil)
        package_basename = File.basename(package)
        if package == relative_to
          ":#{label}"
        elsif package_basename == label
          "//#{package}"
        else
          "//#{package}:#{label}"
        end
      end

      def build_settings_label(config)
        cocoapods_bazel_path = File.join(relative_sandbox_root, 'cocoapods-bazel')

        "//#{cocoapods_bazel_path}:#{config}"
      end

      def test_host
        unless (app_host_info = pod_target.test_app_hosts_by_spec_name[non_library_spec.name])
          return
        end

        app_spec, app_target = *app_host_info
        Target.new(installer, app_target, app_spec, {}, @experimental_deps_debug_and_release)
      end

      def type
        platform = pod_target.platform.name
        case non_library_spec&.spec_type
        when nil
          'apple_framework'
        when :app
          "#{platform}_application"
        when :test
          "#{platform}_#{non_library_spec.test_type}_test"
        else
          raise "Unhandled: #{non_library_spec.spec_type}"
        end
      end

      def dependent_targets_by_config
        targets =
          case non_library_spec&.spec_type
          when nil
            pod_target.dependent_targets_by_config
          when :app
            pod_target.app_dependent_targets_by_spec_name_by_config[non_library_spec.name].transform_values { |v| v + [pod_target] }
          when :test
            pod_target.test_dependent_targets_by_spec_name_by_config[non_library_spec.name].transform_values { |v| v + [pod_target] }
          else
            raise "Unhandled: #{non_library_spec.spec_type}"
          end

        targets.transform_values { |v| v.uniq.map { |target| self.class.new(installer, target) } }
      end

      def product_module_name
        name = resolved_value_by_build_setting('PRODUCT_MODULE_NAME') || resolved_value_by_build_setting('PRODUCT_NAME') ||
               if non_library_spec
                 label.tr('-', '_')
               else
                 pod_target.product_module_name
               end

        raise 'The product module name must be the same for both debug and release.' unless name.is_a? String

        name.gsub(/^([0-9])/, '_\1').gsub(/[^a-zA-Z0-9_]/, '_')
      end

      def swift_objc_bridging_header
        resolved_value_by_build_setting('SWIFT_OBJC_BRIDGING_HEADER')
      end

      def uses_swift?
        file_accessors.any? { |fa| fa.source_files.any? { |s| s.extname == '.swift' } }
      end

      def pod_target_xcconfig_by_build_setting
        debug_xcconfig = resolved_xcconfig(configuration: :debug)
        release_xcconfig = resolved_xcconfig(configuration: :release)
        debug_only_xcconfig = debug_xcconfig.reject { |k, v| release_xcconfig[k] == v }
        release_only_xcconfig = release_xcconfig.reject { |k, v| debug_xcconfig[k] == v }

        xconfig_by_build_setting = {}
        xconfig_by_build_setting[build_settings_label(:debug)] = debug_only_xcconfig unless debug_only_xcconfig.empty?
        xconfig_by_build_setting[build_settings_label(:release)] = release_only_xcconfig unless release_only_xcconfig.empty?
        xconfig_by_build_setting
      end

      def common_pod_target_xcconfig
        debug_xcconfig = resolved_xcconfig(configuration: :debug)
        release_xcconfig = resolved_xcconfig(configuration: :release)
        common_xcconfig = debug_xcconfig.select { |k, v| release_xcconfig[k] == v }
        # If the value is an array, merge it into a string.
        common_xcconfig.map do |k, v|
          [k, v.is_a?(Array) ? v.shelljoin : v]
        end.to_h
      end

      def resolved_xcconfig(configuration:)
        unless resolved_xconfig_by_config[configuration]
          xcconfig = pod_target_xcconfig(configuration: configuration)
          resolved_xconfig_by_config[configuration] = resolve_xcconfig(xcconfig)[1]
        end
        resolved_xconfig_by_config[configuration].clone
      end

      def pod_target_xcconfig(configuration:)
        pod_target
          .build_settings_for_spec(non_library_spec || pod_target.root_spec, configuration: configuration)
          .merged_pod_target_xcconfigs
          .to_h
          .merge(
            'CONFIGURATION' => configuration.to_s.capitalize,
            'PODS_TARGET_SRCROOT' => ':',
            'SRCROOT' => ':',
            'SDKROOT' => '__BAZEL_XCODE_SDKROOT__'
          )
      end

      def resolved_value_by_build_setting(setting, additional_settings: {}, is_label_argument: false)
        debug_settings = pod_target_xcconfig(configuration: :debug).merge(additional_settings)
        debug_value = resolved_build_setting_value(setting, settings: debug_settings)
        release_settings = pod_target_xcconfig(configuration: :release).merge(additional_settings)
        release_value = resolved_build_setting_value(setting, settings: release_settings)
        if debug_value == release_value
          debug_value&.empty? && is_label_argument ? nil : debug_value
        else
          value_by_build_setting = {
            build_settings_label(:debug) => debug_value.empty? && is_label_argument ? nil : debug_value,
            build_settings_label(:release) => release_value.empty? && is_label_argument ? nil : release_value
          }
          StarlarkCompiler::AST::FunctionCall.new('select', value_by_build_setting)
        end
      end

      def pod_target_xcconfig_header_search_paths(configuration)
        settings = pod_target_xcconfig(configuration: configuration).merge('PODS_TARGET_SRCROOT' => @package)
        resolved_build_setting_value('HEADER_SEARCH_PATHS', settings: settings) || []
      end

      def pod_target_xcconfig_user_header_search_paths(configuration)
        settings = pod_target_xcconfig(configuration: configuration).merge('PODS_TARGET_SRCROOT' => @package)
        resolved_build_setting_value('USER_HEADER_SEARCH_PATHS', settings: settings) || []
      end

      def pod_target_copts(type)
        setting =
          case type
          when :swift then 'OTHER_SWIFT_FLAGS'
          when :objc then 'OTHER_CFLAGS'
          else raise "#Unsupported type #{type}"
          end
        copts = resolved_value_by_build_setting(setting)
        copts = [copts] if copts&.is_a?(String)

        debug_copts = copts_for_search_paths_by_config(type, :debug)
        release_copts = copts_for_search_paths_by_config(type, :release)
        copts_for_search_paths =
          if debug_copts.sort == release_copts.sort
            debug_copts
          else
            copts_by_build_setting = {
              build_settings_label(:debug) => debug_copts,
              build_settings_label(:release) => release_copts
            }
            StarlarkCompiler::AST::FunctionCall.new('select', copts_by_build_setting)
          end

        if copts
          if copts.is_a?(Array)
            if copts_for_search_paths.is_a?(Array)
              copts + copts_for_search_paths
            else
              starlark { copts_for_search_paths + copts }
            end
          elsif copts_for_search_paths.is_a?(Array) && copts_for_search_paths.empty?
            copts
          else
            starlark { copts + copts_for_search_paths }
          end
        else
          copts_for_search_paths
        end
      end

      def copts_for_search_paths_by_config(type, configuration)
        additional_flag =
          case type
          when :swift then '-Xcc'
          when :objc then nil
          else raise "#Unsupported type #{type}"
          end

        copts = []
        pod_target_xcconfig_header_search_paths(configuration).each do |path|
          iquote = "-I#{path}"
          copts << additional_flag if additional_flag
          copts << iquote
        end

        pod_target_xcconfig_user_header_search_paths(configuration).each do |path|
          iquote = "-iquote#{path}"
          copts << additional_flag if additional_flag
          copts << iquote
        end
        copts
      end

      def pod_target_infoplists_by_build_setting
        debug_plist = resolved_build_setting_value('INFOPLIST_FILE', settings: pod_target_xcconfig(configuration: :debug))
        release_plist = resolved_build_setting_value('INFOPLIST_FILE', settings: pod_target_xcconfig(configuration: :release))
        if debug_plist == release_plist
          []
        else
          plist_by_build_setting = {}
          plist_by_build_setting[build_settings_label(:debug)] = [debug_plist] if debug_plist
          plist_by_build_setting[build_settings_label(:release)] = [release_plist] if release_plist
          plist_by_build_setting
        end
      end

      def common_pod_target_infoplists(additional_plist: nil)
        debug_plist = resolved_build_setting_value('INFOPLIST_FILE', settings: pod_target_xcconfig(configuration: :debug))
        release_plist = resolved_build_setting_value('INFOPLIST_FILE', settings: pod_target_xcconfig(configuration: :release))
        if debug_plist == release_plist
          [debug_plist, additional_plist].compact
        else
          [additional_plist].compact
        end
      end

      def to_rule_kwargs
        kwargs = RuleArgs.new do |args|
          args
            .add(:name, label)
            .add(:module_name, product_module_name, defaults: [label])
            .add(:module_map, !non_library_spec && file_accessors.map(&:module_map).find(&:itself)&.relative_path_from(@package_dir)&.to_s, defaults: [nil, false]).

            # public headers
            add(:public_headers, glob(attr: :public_headers, sorted: false).yield_self { |f| case f when Array then f.reject { |path| path.include? '.framework/' } else f end }, defaults: [[]])
            .add(:private_headers, glob(attr: :private_headers).yield_self { |f| case f when Array then f.reject { |path| path.include? '.framework/' } else f end }, defaults: [[]])
            .add(:pch, glob(attr: :prefix_header, return_files: true).first, defaults: [nil])
            .add(:data, glob(attr: :resources, exclude_directories: 0), defaults: [[]])
            .add(:resource_bundles, {}, defaults: [{}])
            .add(:swift_version, uses_swift? && pod_target.swift_version, defaults: [nil, false])
            .add(:swift_objc_bridging_header, swift_objc_bridging_header, defaults: [nil])

          # xcconfigs
          resolve_xcconfig(common_pod_target_xcconfig, default_xcconfigs: default_xcconfigs).tap do |name, xcconfig|
            args
              .add(:default_xcconfig_name, name, defaults: [nil])
              .add(:xcconfig, xcconfig, defaults: [{}])
          end
          # xcconfig_by_build_setting
          args.add(:xcconfig_by_build_setting, pod_target_xcconfig_by_build_setting, defaults: [{}])
        end.kwargs

        file_accessors.group_by { |fa| fa.spec_consumer.requires_arc.class }.tap do |fa_by_arc|
          srcs = Hash.new { |h, k| h[k] = [] }
          non_arc_srcs = Hash.new { |h, k| h[k] = [] }
          expand = ->(g) { expand_glob(g, extensions: %w[h hh m mm swift c cc cpp]) }

          Array(fa_by_arc[TrueClass]).each do |fa|
            srcs[fa.spec_consumer.exclude_files] += fa.spec_consumer.source_files.flat_map(&expand)
          end
          Array(fa_by_arc[FalseClass]).each do |fa|
            non_arc_srcs[fa.spec_consumer.exclude_files] += fa.spec_consumer.source_files.flat_map(&expand)
          end
          (Array(fa_by_arc[Array]) + Array(fa_by_arc[String])).each do |fa|
            arc_globs = Array(fa.spec_consumer.requires_arc).flat_map(&expand)
            globs = fa.spec_consumer.source_files.flat_map(&expand)

            srcs[fa.spec_consumer.exclude_files] += arc_globs
            non_arc_srcs[fa.spec_consumer.exclude_files + arc_globs] += globs
          end

          m = lambda do |h|
            h.delete_if do |_, v|
              v.delete_if { |g| g.include?('.framework/') }
              v.empty?
            end
            return [] if h.empty?

            globs = h.values.reduce(:+).uniq
            excludes = h.keys.reduce(:+).uniq
            excludes = excludes.empty? ? {} : { exclude: excludes.flat_map(&method(:expand_glob)) }
            starlark { function_call(:glob, globs, **excludes) }
          end

          kwargs[:srcs] = m[srcs]
          kwargs[:non_arc_srcs] = m[non_arc_srcs]
        end

        file_accessors.each_with_object({}) do |fa, bundles|
          fa.spec_consumer.resource_bundles.each do |name, file_patterns|
            bundle = bundles[name] ||= {}
            patterns_by_exclude = bundle[fa.spec_consumer.exclude_files] ||= []
            patterns_by_exclude.concat(file_patterns.flat_map { |g| expand_glob(g, expand_directories: true) })
          end
        end.tap do |bundles|
          kwargs[:resource_bundles] = bundles.map do |bundle_name, patterns_by_excludes|
            patterns_by_excludes.delete_if { |_, v| v.empty? }
            # resources implicitly have dirs expanded by CocoaPods
            resources = patterns_by_excludes.map do |excludes, globs|
              excludes = excludes.empty? ? {} : { exclude: excludes.flat_map(&method(:expand_glob)) }
              starlark { function_call(:glob, globs.uniq, exclude_directories: 0, **excludes) }
            end.reduce(&:+)
            [bundle_name, resources]
          end.to_h
        end

        # non-propagated stuff for a target that should build.
        if pod_target.should_build?
          kwargs[:swift_copts] = pod_target_copts(:swift)
          kwargs[:objc_copts] = pod_target_copts(:objc)
          linkopts = resolved_value_by_build_setting('OTHER_LDFLAGS')
          linkopts = [linkopts] if linkopts.is_a? String
          kwargs[:linkopts] = linkopts || []
        end

        # propagated
        kwargs[:defines] = []
        kwargs[:other_inputs] = []
        kwargs[:linking_style] = nil
        kwargs[:runtime_deps] = []
        kwargs[:sdk_dylibs] = file_accessors.flat_map { |fa| fa.spec_consumer.libraries }.sort.uniq
        kwargs[:sdk_frameworks] = file_accessors.flat_map { |fa| fa.spec_consumer.frameworks }.sort.uniq
        kwargs[:testonly] = true if (kwargs[:sdk_frameworks].include? 'XCTest') && @enable_add_testonly
        kwargs[:sdk_includes] = []
        kwargs[:weak_sdk_frameworks] = file_accessors.flat_map { |fa| fa.spec_consumer.weak_frameworks }.sort.uniq
        kwargs[:testonly] = true if (kwargs[:weak_sdk_frameworks].include? 'XCTest') && @enable_add_testonly

        kwargs[:vendored_static_frameworks] = glob(attr: :vendored_static_frameworks, return_files: true)
        kwargs[:vendored_dynamic_frameworks] = glob(attr: :vendored_dynamic_frameworks, return_files: true)
        kwargs[:vendored_static_libraries] = glob(attr: :vendored_static_libraries, return_files: true)
        kwargs[:vendored_dynamic_libraries] = glob(attr: :vendored_dynamic_libraries, return_files: true)
        kwargs[:vendored_xcframeworks] = vendored_xcframeworks

        # any compatible provider: CCProvider, SwiftInfo, etc
        kwargs[:deps] = deps_by_config

        case non_library_spec&.spec_type
        when :test
          kwargs.merge!(test_kwargs)
        when :app
          kwargs.merge!(app_kwargs)
        when nil
          kwargs.merge!(framework_kwargs)
        end

        defaults = self.defaults
        kwargs.delete_if { |k, v| defaults[k] == v }
        kwargs
      end

      def defaults
        {
          module_name: label,
          module_map: nil,
          srcs: [],
          non_arc_srcs: [],
          hdrs: [],
          pch: nil,
          data: [],
          resource_bundles: {},

          swift_copts: [],
          objc_copts: [],
          cc_copts: [],
          defines: [],
          linkopts: [],
          other_inputs: [],
          linking_style: nil,
          runtime_deps: [],
          sdk_dylibs: [],
          sdk_frameworks: [],
          sdk_includes: [],
          weak_sdk_frameworks: [],

          bundle_id: nil,
          env: {},
          infoplists_by_build_setting: [],
          infoplists: [],
          minimum_os_version: nil,
          test_host: nil,
          platforms: {},

          app_icons: [],
          bundle_name: nil,
          entitlements: nil,
          entitlements_validation: nil,
          extensions: [],
          frameworks: [],
          ipa_post_processor: nil,
          launch_images: [],
          launch_storyboard: nil,
          provisioning_profile: nil,
          resources: [],
          settings_bundle: [],
          strings: [],
          version: [],
          watch_application: [],

          vendored_static_frameworks: [],
          vendored_dynamic_frameworks: [],
          vendored_static_libraries: [],
          vendored_dynamic_libraries: [],
          vendored_xcframeworks: [],

          deps: []
        }
      end

      def deps_by_config
        debug_targets = dependent_targets_by_config[:debug]
        release_targets = dependent_targets_by_config[:release]

        debug_labels = debug_targets.map { |dt| dt.bazel_label(relative_to: package) }
        release_labels = release_targets.map { |dt| dt.bazel_label(relative_to: package) }
        shared_labels = (debug_labels & release_labels).uniq

        debug_only_labels = debug_labels - shared_labels
        release_only_labels = release_labels - shared_labels

        sorted_debug_labels = Pod::Bazel::Util.sort_labels(debug_only_labels)
        sorted_release_labels = Pod::Bazel::Util.sort_labels(release_only_labels)
        sorted_shared_labels = Pod::Bazel::Util.sort_labels(shared_labels)

        labels_by_config = {}

        if !sorted_debug_labels.empty? || !sorted_release_labels.empty?
          if @experimental_deps_debug_and_release
            labels_by_config[build_settings_label(:deps_debug)] = sorted_debug_labels
            labels_by_config[build_settings_label(:deps_release)] = sorted_release_labels
            labels_by_config[build_settings_label(:deps_debug_and_release)] = sorted_debug_labels + sorted_release_labels
          else
            labels_by_config[build_settings_label(:debug)] = sorted_debug_labels
            labels_by_config[build_settings_label(:release)] = sorted_release_labels
          end
        end

        if labels_by_config.empty? # no per-config dependency
          sorted_shared_labels
        elsif sorted_shared_labels.empty? # per-config dependencies exist, avoiding adding an empty array
          StarlarkCompiler::AST::FunctionCall.new('select', labels_by_config)
        else # both per-config and shared dependencies exist
          starlark { StarlarkCompiler::AST::FunctionCall.new('select', labels_by_config) + sorted_shared_labels }
        end
      end

      def glob(attr:, return_files: !pod_target.sandbox.local?(pod_target.pod_name), sorted: true, excludes: [], exclude_directories: 1)
        if !return_files
          case attr
          when :public_headers then attr = :public_header_files
          when :private_headers then attr = :private_header_files
          end

          globs = file_accessors.map(&:spec_consumer).flat_map(&attr).flat_map { |g| expand_glob(g, expand_directories: exclude_directories != 1) }
          excludes += file_accessors.map(&:spec_consumer).flat_map(&:exclude_files).flat_map { |g| expand_glob(g) }
          excludes = excludes.empty? ? {} : { exclude: excludes }
          excludes[:exclude_directories] = exclude_directories unless exclude_directories == 1
          if globs.empty?
            []
          else
            starlark { function_call(:glob, globs, **excludes) }
          end
        else
          file_accessors.flat_map(&attr)
                        .compact
                        .map { |path| path.relative_path_from(@package_dir).to_s }
                        .yield_self { |paths| sorted ? paths.sort : paths }
                        .uniq
        end
      end

      def expand_glob(glob, extensions: nil, expand_directories: false)
        if (m = glob.match(/\{([^\{\}]+)\}/))
          m[1].split(',').flat_map do |alt|
            expand_glob("#{m.pre_match}#{alt.strip}#{m.post_match}", extensions: extensions, expand_directories: expand_directories)
          end.uniq
        elsif (m = glob.match(/\[([^\[\]]+)\]/))
          m[1].each_char.flat_map do |alt|
            expand_glob("#{m.pre_match}#{alt.strip}#{m.post_match}", extensions: extensions, expand_directories: expand_directories)
          end.uniq
        elsif extensions && File.extname(glob).empty?
          glob = glob.chomp('**/*') # If we reach here and the glob ends with **/*, we need to avoid duplicating it (we do not want to end up with **/*/**/*)
          if File.basename(glob) == '*'
            extensions.map do |ext|
              combined = "#{glob}.#{ext}"
              combined if Dir.glob(File.join(@package_dir, combined)).any?
            end.compact
          else
            extensions.map do |ext|
              combined = File.join(glob, '**', "*.#{ext}")
              combined if Dir.glob(File.join(@package_dir, combined)).any?
            end.compact
          end
        elsif expand_directories
          if glob.end_with?('/**/*')
            glob_with_valid_matches(glob)
          elsif glob.end_with?('/*')
            [glob.sub(%r{/\*$}, '/**/*')]
          elsif should_skip_directory_expansion(glob)
            glob_with_valid_matches(glob)
          else
            [glob.chomp('/') + '/**/*']
          end
        else
          glob_with_valid_matches(glob)
        end
      end

      # Returns `[glob]` if the given pattern has at least 1 match on disk, otherwise returns an empty array
      def glob_with_valid_matches(glob)
        Dir.glob(File.join(@package_dir, glob)).any? ? [glob] : []
      end

      # We should expand only folder globs, not expand file globs.
      # E.g., xib files glob "*.xib" should not be expanded to "*.xib/**/*", otherise nothing will be matched
      def should_skip_directory_expansion(glob)
        extension = File.extname(glob)
        expansion_extentions = Set['.xcassets', '.xcdatamodeld', '.lproj']
        !expansion_extentions.include?(extension)
      end

      def rules_ios_platform_name(platform)
        name = platform.string_name.downcase
        return 'macos' if name == 'osx'

        name
      end

      def framework_kwargs
        library_spec = pod_target.file_accessors.find { |fa| fa.spec.library_specification? }.spec
        {
          visibility: ['//visibility:public'],
          bundle_id: resolved_value_by_build_setting('PRODUCT_BUNDLE_IDENTIFIER'),
          infoplists_by_build_setting: pod_target_infoplists_by_build_setting,
          infoplists: common_pod_target_infoplists(additional_plist: nil_if_empty(library_spec.consumer(pod_target.platform).info_plist)),
          platforms: { rules_ios_platform_name(pod_target.platform) => build_os_version || pod_target.platform.deployment_target.to_s }
        }
      end

      def test_kwargs
        {
          bundle_id: resolved_value_by_build_setting('PRODUCT_BUNDLE_IDENTIFIER'),
          env: resolve_env(pod_target.scheme_for_spec(non_library_spec).fetch(:environment_variables, {})),
          infoplists_by_build_setting: pod_target_infoplists_by_build_setting,
          infoplists: common_pod_target_infoplists(additional_plist: nil_if_empty(non_library_spec.consumer(pod_target.platform).info_plist)),
          minimum_os_version: build_os_version || pod_target.deployment_target_for_non_library_spec(non_library_spec),
          test_host: test_host&.bazel_label(relative_to: package) || file_accessors.any? { |fa| fa.spec_consumer.requires_app_host? } || nil
        }
      end

      # Resolves the given environment by resolving CocoaPod specific environment variables.
      # Given an environment with unresolved env values, this function resolves them and returns the new env.
      def resolve_env(env)
        # These environment variables are resolved by CocoaPods, they tend to be used in tests and other
        # scripts, as such we must resolve them before translating the targets environment.
        resolved_cocoapods_env = {
          'PODS_ROOT' => "//#{relative_sandbox_root}",
          'PODS_TARGET_SRCROOT' => ':'
        }.freeze

        # Removes the : bazel prefix for current directory.
        sub_prefix = ->(s) { s.sub(%r{\A:/}, '') }

        env.each_with_object({}) do |(k, v), resolved_env|
          resolved_val = Pod::Bazel::Util.resolve_value(v, resolved_values: resolved_cocoapods_env)
          resolved_env[k] = sub_prefix[resolved_val]
        end
      end

      def build_os_version
        # If there's a SWIFT_DEPLOYMENT_TARGET version set, use that for the
        # minimum version. It's not currently supported or desirable in rules_ios to have
        # these distinct, however xcconfig supports that.
        swift_deployment_target = resolved_value_by_build_setting('SWIFT_DEPLOYMENT_TARGET')

        llvm_target_triple_os_version = resolved_value_by_build_setting('LLVM_TARGET_TRIPLE_OS_VERSION')
        if llvm_target_triple_os_version
          # For clang this is set ios9.0: take everything after the os name
          version_number = llvm_target_triple_os_version.match(/\d.*/)
          clang_build_os_version = version_number.to_s if version_number
        end
        if !swift_deployment_target.nil? && !clang_build_os_version.nil?
          raise "warning: had different os versions #{swift_deployment_target} #{clang_build_os_version}" if swift_deployment_target != clang_build_os_version
        end
        swift_deployment_target || clang_build_os_version
      end

      def app_kwargs
        # maps to kwargs listed for https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_application

        platform_target = pod_target.deployment_target_for_non_library_spec(non_library_spec)

        kwargs = {
          app_icons: [],
          bundle_id: resolved_value_by_build_setting('PRODUCT_BUNDLE_IDENTIFIER') || "org.cocoapods.#{label}",
          bundle_name: nil,
          entitlements: resolved_value_by_build_setting('CODE_SIGN_ENTITLEMENTS', is_label_argument: true),
          entitlements_validation: nil,
          extensions: [],
          families: app_targeted_device_families,
          frameworks: [],
          infoplists_by_build_setting: pod_target_infoplists_by_build_setting,
          infoplists: common_pod_target_infoplists(additional_plist: nil_if_empty(non_library_spec.consumer(pod_target.platform).info_plist)),
          ipa_post_processor: nil,
          launch_images: [],
          launch_storyboard: nil,
          minimum_os_version: build_os_version || platform_target,
          provisioning_profile: nil,
          resources: [],
          settings_bundle: [],
          strings: [],
          version: [],
          watch_application: [],
          visibility: ['//visibility:public']
        }

        # If the user has set a different build os set that here
        kwargs[:minimum_deployment_os_version] = platform_target if build_os_version
        kwargs
      end

      def app_targeted_device_families
        # Reads the targeted device families from xconfig TARGETED_DEVICE_FAMILY. Supports both iphone and ipad by default.
        device_families = resolved_value_by_build_setting('TARGETED_DEVICE_FAMILY') || '1,2'
        raise 'TARGETED_DEVICE_FAMILY must be the same for both debug and release.' unless device_families.is_a? String

        device_families.split(',').map do |device_family|
          case device_family
          when '1' then 'iphone'
          when '2' then 'ipad'
          else raise "Unsupported device family: #{device_family}"
          end
        end
      end

      def vendored_xcframeworks
        pod_target.xcframeworks.values.flatten(1).uniq.map do |xcframework|
          {
            'name' => xcframework.name,
            'slices' => xcframework.slices.map do |slice|
              platform_name = rules_ios_platform_name(slice.platform)
              if @xcframework_excluded_platforms.include?(platform_name)
                nil
              else
                {
                  'identifier' => slice.identifier,
                  'platform' => platform_name,
                  'platform_variant' => slice.platform_variant.to_s,
                  'supported_archs' => slice.supported_archs,
                  'path' => slice.path.relative_path_from(@package_dir).to_s,
                  'build_type' => { 'linkage' => slice.build_type.linkage.to_s, 'packaging' => slice.build_type.packaging.to_s }
                }
              end
            end.compact
          }
        end
      end

      def nil_if_empty(arr)
        arr.empty? ? nil : arr
      end

      def starlark(&blk)
        StarlarkCompiler::AST.build(&blk)
      end
    end
  end
end

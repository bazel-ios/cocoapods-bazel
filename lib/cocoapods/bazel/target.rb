# frozen_string_literal: true

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

      attr_reader :installer, :pod_target, :file_accessors, :non_library_spec, :label, :package
      private :installer, :pod_target, :file_accessors, :non_library_spec, :label, :package

      def initialize(installer, pod_target, non_library_spec = nil)
        @installer = installer
        @pod_target = pod_target
        @file_accessors = non_library_spec ? pod_target.file_accessors.select { |fa| fa.spec == non_library_spec } : pod_target.file_accessors.select { |fa| fa.spec.library_specification? }
        @non_library_spec = non_library_spec
        @label = (non_library_spec ? pod_target.non_library_spec_label(non_library_spec) : pod_target.label)
        @package_dir = installer.sandbox.pod_dir(pod_target.pod_name)
        @package = installer.sandbox.pod_dir(pod_target.pod_name).relative_path_from(installer.config.installation_root).to_s
      end

      def bazel_label
        package_basename = File.basename(package)
        if package_basename == label
          "//#{package}"
        # elsif label.start_with(package_basename)
        #   "//#{package}:#{label.sub(/#{Regexp.escape package_basename}[-_]/)}"
        else
          "//#{package}:#{label}"
        end
      end

      def test_host
        unless (app_host_info = pod_target.test_app_hosts_by_spec_name[non_library_spec.name])
          return
        end

        app_spec, app_target = *app_host_info
        Target.new(installer, app_target, app_spec)
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

      def dependent_targets
        targets =
          case non_library_spec&.spec_type
          when nil
            pod_target.dependent_targets
          when :app
            pod_target.app_dependent_targets_by_spec_name[non_library_spec.name] + [pod_target]
          when :test
            pod_target.test_dependent_targets_by_spec_name[non_library_spec.name] + [pod_target]
          else
            raise "Unhandled: #{non_library_spec.spec_type}"
          end

        targets.uniq.map { |target| self.class.new(installer, target) }
      end

      def product_module_name
        name = resolved_build_setting_value('PRODUCT_MODULE_NAME') || resolved_build_setting_value('PRODUCT_NAME') ||
               if non_library_spec
                 label.tr('-', '_')
               else
                 pod_target.product_module_name
               end

        name.gsub(/^([0-9])/, '_\1').gsub(/[^a-zA-Z0-9_]/, '_')
      end

      def uses_swift?
        file_accessors.any? { |fa| fa.source_files.any? { |s| s.extname == '.swift' } }
      end

      def pod_target_xcconfig
        pod_target
          .build_settings_for_spec(non_library_spec || pod_target.root_spec, configuration: :debug)
          .merged_pod_target_xcconfigs
          .merge('CONFIGURATION' => 'Debug')
      end

      def resolved_build_setting_value(setting)
        # TODO: handle both configs
        settings = pod_target_xcconfig
                   .merge(
                     'SRCROOT' => ':',
                     'PODS_TARGET_SRCROOT' => ':'
                   )

        return unless (value = settings[setting])

        resolve_string_with_build_settings(value, settings: settings).sub(%r{\A:/}, '')
      end

      def resolve_string_with_build_settings(string, settings: pod_target_xcconfig)
        return string unless string =~ /\$(?:\{([_a-zA-Z0-0]+?)\}|\(([_a-zA-Z0-0]+?)\))/

        match, key = Regexp.last_match.values_at(0, 1, 2).compact
        sub = settings.fetch(key, '')
        resolve_string_with_build_settings(string.gsub(match, sub), settings: settings)
      end

      def to_rule_kwargs
        kwargs = RuleArgs.new do |args|
          args
            .add(:name, label).
            # foo
            add(:module_name, product_module_name, defaults: [label]).
            # bar
            add(:module_map, file_accessors.map(&:module_map).find(&:itself)&.relative_path_from(@package_dir)&.to_s, defaults: [nil]).

            # public headers
            add(:public_headers, glob(attr: :public_headers, sorted: false).yield_self { |f| case f when Array then f.reject { |path| path.include? '.framework/' } else f end }, defaults: [[]])
            .add(:private_headers, glob(attr: :private_headers).yield_self { |f| case f when Array then f.reject { |path| path.include? '.framework/' } else f end }, defaults: [[]])
            .add(:pch, glob(attr: :prefix_header, return_files: true).first, defaults: [nil])
            .add(:data, glob(attr: :resources), defaults: [[]])
            .add(:resource_bundles, {}, defaults: [{}])
            .add(:swift_version, uses_swift? && pod_target.swift_version, defaults: [nil, false]).

            kwargs
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

            h.map do |excludes, globs|
              excludes = excludes.empty? ? {} : { exclude: excludes.flat_map(&method(:expand_glob)) }
              starlark { function_call(:glob, globs.uniq, **excludes) }
            end.reduce(&:+)
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
              starlark { function_call(:glob, globs.uniq, **excludes) }
            end.reduce(&:+)
            [bundle_name, resources]
          end.to_h
        end

        # non-propagated stuff
        kwargs[:swift_copts] = resolved_build_setting_value('OTHER_SWIFT_FLAGS')&.shellsplit || []
        kwargs[:objc_copts] = resolved_build_setting_value('OTHER_CFLAGS')&.shellsplit || []
        # kwargs[:cc_copts] = resolve_string_with_build_settings('${OTHER_CFLAGS} ${OTHER_CPPFLAGS}')&.shellsplit || []

        # propagated
        kwargs[:defines] = []
        kwargs[:linkopts] = []
        kwargs[:other_inputs] = []
        kwargs[:linking_style] = nil
        kwargs[:runtime_deps] = []
        kwargs[:sdk_dylibs] = file_accessors.flat_map { |fa| fa.spec_consumer.libraries }.sort.uniq
        kwargs[:sdk_frameworks] = file_accessors.flat_map { |fa| fa.spec_consumer.frameworks }.sort.uniq
        kwargs[:sdk_includes] = []
        kwargs[:weak_sdk_frameworks] = file_accessors.flat_map { |fa| fa.spec_consumer.weak_frameworks }.sort.uniq

        kwargs[:vendored_static_frameworks] = glob(attr: :vendored_static_frameworks, return_files: true)
        kwargs[:vendored_dynamic_frameworks] = glob(attr: :vendored_dynamic_frameworks, return_files: true)
        kwargs[:vendored_static_libraries] = glob(attr: :vendored_static_libraries, return_files: true)
        kwargs[:vendored_dynamic_libraries] = glob(attr: :vendored_dynamic_libraries, return_files: true)

        # any compatible provider: CCProvider, SwiftInfo, etc
        kwargs[:deps] = dependent_targets.map(&:bazel_label).sort

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
          infoplists: [],
          minimum_os_version: nil,
          test_host: nil,

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

          deps: []
        }
      end

      def glob(attr:, return_files: !pod_target.sandbox.local?(pod_target.pod_name), sorted: true, excludes: [])
        if !return_files
          case attr
          when :public_headers then attr = :public_header_files
          when :private_headers then attr = :private_header_files
          end

          globs = file_accessors.map(&:spec_consumer).flat_map(&attr).flat_map { |g| expand_glob(g) }
          excludes += file_accessors.map(&:spec_consumer).flat_map(&:exclude_files).flat_map { |g| expand_glob(g) }
          excludes = excludes.empty? ? {} : { exclude: excludes }
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
            expand_glob("#{m.pre_match}#{alt}#{m.post_match}")
          end.uniq
        elsif extensions && File.extname(glob).empty?
          extensions.map do |ext|
            File.join(glob, '**', "*.#{ext}")
          end
        elsif expand_directories
          if glob.end_with?('/**/*')
            [glob]
          elsif glob.end_with?('/*')
            [glob.sub(%r{/\*$}, '/**/*')]
          else
            [glob, glob.chomp('/') + '/**/*']
          end
        else
          [glob]
        end
      end

      def framework_kwargs
        {
          visibility: ['//visibility:public']
        }
      end

      def test_kwargs
        {
          bundle_id: resolved_build_setting_value('PRODUCT_BUNDLE_IDENTIFIER'),
          env: pod_target.scheme_for_spec(non_library_spec).fetch(:environment_variables, {}),
          infoplists: [resolved_build_setting_value('INFOPLIST_FILE')].compact,
          minimum_os_version: pod_target.platform.deployment_target.to_s,
          test_host: test_host&.bazel_label || file_accessors.any? { |fa| fa.spec_consumer.requires_app_host? } || nil
        }
      end

      def app_kwargs
        {
          app_icons: [],
          bundle_id: resolved_build_setting_value('PRODUCT_BUNDLE_IDENTIFIER'),
          bundle_name: nil,
          entitlements: resolved_build_setting_value('CODE_SIGN_ENTITLEMENTS'),
          entitlements_validation: nil,
          extensions: [],
          families: %w[iphone ipad],
          frameworks: [],
          infoplists: [resolved_build_setting_value('INFOPLIST_FILE')].compact,
          ipa_post_processor: nil,
          launch_images: [],
          launch_storyboard: nil,
          linkopts: [],
          minimum_os_version: pod_target.platform.deployment_target.to_s,
          provisioning_profile: nil,
          resources: [],
          settings_bundle: [],
          strings: [],
          version: [],
          watch_application: []
        }
      end

      def arr_or_nil(arr)
        arr.empty? ? nil : arr
      end

      def starlark(&blk)
        StarlarkCompiler::AST.build(&blk)
      end
    end
  end
end

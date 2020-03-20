# frozen_string_literal: true

require 'starlark_compiler/build_file'
require 'cocoapods/bazel/config'
require 'cocoapods/bazel/target'
require 'cocoapods/bazel/xcconfig_resolver'

module Pod
  module Bazel
    def self.post_install(installer:)
      return unless (config = Config.from_podfile(installer.podfile))

      default_xcconfigs = config.default_xcconfigs.transform_values do |xcconfig|
        _name, xcconfig = XCConfigResolver.resolve_xcconfig(xcconfig)
        xcconfig
      end

      UI.titled_section 'Generating Bazel files' do
        workspace = installer.config.installation_root
        sandbox = installer.sandbox
        build_files = Hash.new { |h, k| h[k] = StarlarkCompiler::BuildFile.new(workspace: workspace, package: k) }
        installer.pod_targets.each do |pod_target|
          package = sandbox.pod_dir(pod_target.pod_name).relative_path_from(workspace).to_s
          build_file = build_files[package]

          bazel_targets = [Target.new(installer, pod_target, nil, default_xcconfigs)] +
                          pod_target.file_accessors.reject { |fa| fa.spec.library_specification? }.map { |fa| Target.new(installer, pod_target, fa.spec, default_xcconfigs) }

          bazel_targets.each do |t|
            load = config.load_for(macro: t.type)
            build_file.add_load(of: load[:rule], from: load[:load])
            build_file.add_target StarlarkCompiler::AST::FunctionCall.new(load[:rule], **t.to_rule_kwargs)
          end
        end

        unless default_xcconfigs.empty?
          hash = StarlarkCompiler::AST.new(toplevel: [
                                             StarlarkCompiler::AST::Dictionary.new(default_xcconfigs)
                                           ])

          pkg = File.join(sandbox.root, 'cocoapods-bazel')
          FileUtils.mkdir_p pkg
          FileUtils.touch(File.join(pkg, 'BUILD.bazel'))
          File.open(File.join(pkg, 'default_xcconfigs.bzl'), 'w') do |f|
            f << <<~STARLARK
              """
              Default xcconfigs given as options to cocoapods-bazel.
              """

            STARLARK
            f << 'DEFAULT_XCCONFIGS = '
            StarlarkCompiler::Writer.write(ast: hash, io: f)
          end
        end

        build_files.each_value(&:save!)
        format_files(build_files: build_files, buildifier: config.buildifier, workspace: workspace)
      end
    end

    def self.format_files(build_files:, buildifier:, workspace:)
      return if build_files.empty?

      args = []
      case buildifier
      when true
        return unless Pod::Executable.which('buildifier')

        args = ['buildifier']
      when String, Array
        args = Array(buildifier)
      else
        return
      end
      args += %w[-type build]

      executable, *args = args
      Pod::Executable.execute_command executable,
                                      args + build_files.each_key.map { |d| File.join workspace, d, 'BUILD.bazel' },
                                      true
    end
  end
end

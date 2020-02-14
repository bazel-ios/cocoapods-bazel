# frozen_string_literal: true

require 'starlark_compiler/build_file'
require 'cocoapods/bazel/config'
require 'cocoapods/bazel/target'

module Pod
  module Bazel
    def self.post_install(installer:)
      return unless (config = Config.from_podfile(installer.podfile))

      UI.titled_section 'Generating Bazel files' do
        workspace = installer.config.installation_root
        sandbox = installer.sandbox
        build_files = Hash.new { |h, k| h[k] = StarlarkCompiler::BuildFile.new(workspace: workspace, package: k) }
        installer.pod_targets.each do |pod_target|
          package = sandbox.pod_dir(pod_target.pod_name).relative_path_from(workspace).to_s
          build_file = build_files[package]

          bazel_targets = [Target.new(installer, pod_target)] +
                          pod_target.file_accessors.reject { |fa| fa.spec.library_specification? }.map { |fa| Target.new(installer, pod_target, fa.spec) }

          bazel_targets.each do |t|
            load = config.load_for(macro: t.type)
            build_file.add_load(of: load[:rule], from: load[:load])
            build_file.add_target StarlarkCompiler::AST::FunctionCall.new(load[:rule], **t.to_rule_kwargs)
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

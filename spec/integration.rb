# frozen_string_literal: true

# ------------------------------------- #
#  cocoapods-bazel Integration tests    #
# ------------------------------------- #

#-----------------------------------------------------------------------------#

# The following integrations tests are based on file comparison.
#
# 1.  For each test there is a folder with a `before` and `after` subfolders.
# 2.  The contents of the before folder are copied to the `TMP_DIR` folder and
#     then the given arguments are passed to the `POD_BINARY`.
# 3.  After the pod command completes the execution the each file in the
#     `after` subfolder is compared to be to the contents of the temporary
#     directory.  If the contents of the file do not match an error is
#     registered. Xcode projects are compared in an UUID agnostic way.
#
# Notes:
#
# - The output of the pod command could be saved in the `execution_output.txt` file
#   which should be added to the `after` folder to test the CocoaPods UI.
# - To create a new test, just create a before folder with the environment to
#   test, copy it to the after folder and run the tested pod command inside.
#
# Rationale:
#
# - Have a way to track precisely the evolution of the artifacts (and of the
#   UI) produced by CocoaPods (git diff of the after folders).
# - Allow users to submit pull requests with the environment necessary to
#   reproduce an issue.
# - Have robust tests which don't depend on the programmatic interface of
#   CocoaPods. These tests depend only the binary and its arguments and thus are
#   suitable for testing CP regardless of the implementation (they could even
#   work for an Objective-C one)

#-----------------------------------------------------------------------------#

require 'rubygems'
require 'bundler/setup'

require 'CLIntegracon'
require 'colored2'
require 'pathname'
require 'pretty_bacon'

spec_dir = Pathname(__dir__)

require 'cocoapods-core/lockfile'
require 'cocoapods-core/yaml_helper'
require 'xcodeproj'

require_relative 'spec_helper/prepare_spec_repos'
cocoapods_bazel_specs_prepare_spec_repos

class BuildFileMatcher < Regexp
  def match(path)
    case File.basename(path)
    when 'Podfile', /^bazel-/
      true
    when 'WORKSPACE', 'BUILD.bazel', /.*\.bzl$/
      false
    else
      !File.extname(path).empty?
    end
  end
end

CLIntegracon.configure do |c|
  c.spec_path = spec_dir + 'integration'
  c.temp_path = c.spec_path + 'tmp'

  c.ignores BuildFileMatcher.new('_unused')
  c.include_hidden_files = false

  c.hook_into :bacon
end

describe_cli 'pod' do
  subject do |s|
    s.executable = File.expand_path('../bin/pod_install_bazel_build', __dir__)
    s.environment_vars = {
      'CLAIDE_DISABLE_AUTO_WRAP' => 'TRUE',
      'COCOAPODS_SKIP_CACHE' => 'TRUE',
      'COCOAPODS_VALIDATOR_SKIP_XCODEBUILD' => 'TRUE',
      'CP_REPOS_DIR' => cocoapods_bazel_specs_cp_repos_dir
    }
    s.default_args = [
      '--verbose',
      '--no-ansi'
    ]
    s.replace_path spec_dir.parent.to_s, '.'
    s.replace_path `which git`.chomp, 'GIT_BIN'
    s.replace_path `which bash`.chomp, 'BASH_BIN'
    s.replace_path `which curl`.chomp, 'CURL_BIN'
    s.replace_user_path 'Library/Caches/CocoaPods', '~/Library/Caches/CocoaPods'
    s.replace_pattern(%r{#{Dir.tmpdir}/[\w-]+}io, '$TMPDIR') unless Dir.tmpdir == '/tmp'

    # This was changed in a very recent git version
    s.replace_pattern(/git checkout -b <new-branch-name>/, 'git checkout -b new_branch_name')
    s.replace_pattern(/[ \t]+(\r?$)/, '\1')

    # git sometimes prints this, but not always
    s.replace_pattern(/^\s*Checking out files.*done\./, '')

    s.replace_path(%r{
      `[^`]*? # The opening backtick on a plugin path
      ([[[:alnum:]]_+-]+?) # The plugin name
      (- ([[:xdigit:]]+ | #{Gem::Version::VERSION_PATTERN}))? # The version or SHA
      /lib/cocoapods_plugin.rb # The actual plugin file that gets loaded
    }iox, '`\1/lib/cocoapods_plugin.rb')

    s.replace_pattern(/
      ^(\s* \$ \s (CURL_BIN | #{`which curl`.strip}) .* \n)
      ^\s* % \s* Total .* \n
      ^\s* Dload \s* Upload .* \n
      (^\s* [[:cntrl:]] .* \n)+
    /iox, "\\1\n")
  end

  at_exit do
    # clean up git directories from preparing the specs repos
    FileUtils.rm_rf Dir[File.join(cocoapods_bazel_specs_cp_repos_dir, '*', '.git')]
  end

  spec_dir.join('integration').each_child do |dir|
    next unless dir.directory?

    yml_file = dir.join('spec.yml')
    next unless yml_file.file?

    spec = Pod::YAMLHelper.load_file(yml_file)

    describe spec['description'] do
      behaves_like cli_spec File.basename(dir), spec.fetch('args', 'install')
    end
  end
end

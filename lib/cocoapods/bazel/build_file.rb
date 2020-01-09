# frozen_string_literal: true

require 'starlark_compiler/ast'
require 'starlark_compiler/writer'

module Pod
  module Bazel
    class BuildFile
      AST = StarlarkCompiler::AST

      def initialize(package:, workspace: Dir.pwd)
        @loads = Hash.new { |h, k| h[k] = Set.new }
        @targets = {}
        @package = package
        @workspace = workspace
        @path = File.join(@workspace, @package, 'BUILD.bazel')
      end

      def add_load(from:, of:)
        # load_call = @ast.toplevel.find { |node| node.is_a?(AST::FunctionCall) && node.name == 'load' && node.args.first == AST::String.new(from) } ||
        #     AST.build { function_call('load', from) }.tap { |n| @ast << n }
        # load_call.args.concat(Array(of).map { |s| AST::String.new(s) }).sort!.uniq!
        @loads[from] |= Array(of)
      end

      def add_target(function_call)
        name = function_call.kwargs[:name]
        raise if @targets[name]

        @targets[name] = function_call
      end

      def save!
        File.open(@path, 'w') do |f|
          StarlarkCompiler::Writer.write(ast: to_starlark, io: f)
        end
      end

      def to_starlark
        AST.new(toplevel:
            @loads.sort_by { |k, _| k }.map { |f, fn| AST.build { function_call('load', f, *fn.sort) } } +
            @targets.sort_by { |k, _| k }.map { |_f, fn| fn })
      end
    end
  end
end

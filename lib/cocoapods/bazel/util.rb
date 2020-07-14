# frozen_string_literal: true

module Pod
  module Bazel
    module Util
      module_function

      def sort_labels(labels)
        sort_keys = labels.map.with_index { |string, i| SortKey.new(string, i) }
        sort_keys.sort_by { |k| [k.phase, k.split, k.value, k.original_index] }.map(&:value)
      end

      class SortKey
        attr_reader :phase, :split, :value, :original_index

        def initialize(string, index)
          @value = string
          @original_index = index
          @phase = if string.start_with?(':')
                     1
                   elsif string.start_with?('//')
                     2
                   elsif string.start_with?('@')
                     3
                   else
                     4
                   end

          @split = string.split(/[:.]/)
        end
      end
    end
  end
end

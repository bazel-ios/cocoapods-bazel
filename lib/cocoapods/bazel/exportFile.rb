require 'set'

module Pod
  module Bazel
    class ExportFile
      def initialize(file_path)
        @files = []
        @file_path = file_path
      end

      def add(value)
        @files << value
      end
      
      def save
        File.open(@file_path, "w") { |f|
          f.write "exports_files("
          f.write "["
          @files.each do |file|
            f.write "\"#{file}\","  
          end
          f.write "],"
          f.write "visibility = [\"//visibility:public\"],"
          f.write ")"
        }
      end
    end
  end
end

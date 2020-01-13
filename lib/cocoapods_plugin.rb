# frozen_string_literal: true

require 'cocoapods'
require 'cocoapods/bazel'

module Pod
  class Installer
    method_name = :perform_post_install_actions
    unless method_defined?(method_name) || private_method_defined?(method_name)
      raise Informative, <<~MSG
        cocoapods-bazel is incompatible with this version of CocoaPods.
        It requires a version with #{self}##{method_name} defined.
        Please file an issue at https://github.com/ob/cocoapods-bazel for compatibiltiy with this verion of CocoaPods
      MSG
    end

    unbound_method = instance_method(method_name)
    remove_method(method_name)
    define_method(method_name) do
      Pod::Bazel.post_install(installer: self)
      unbound_method.bind(self).call
    end
  end
end

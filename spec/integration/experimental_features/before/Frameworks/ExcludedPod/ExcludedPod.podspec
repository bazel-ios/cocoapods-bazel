# frozen_string_literal: true

Pod::Spec.new do |s|
    s.name = 'ExcludedPod'
    s.version = '1.0.0.LOCAL'

    s.authors = %w[Square]
    s.homepage = 'https://github.com/Square/cocoapods-generate'
    s.source = { git: 'https://github.com/Square/cocoapods-generate' }
    s.summary = 'Testing pod'

    s.swift_versions = %w[5.2]
    s.ios.deployment_target = '9.0'

    s.source_files = ["ExcludedPod.h"]
  end

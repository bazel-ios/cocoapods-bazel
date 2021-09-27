# frozen_string_literal: true

Pod::Spec.new do |s|
    s.name = 'EsotericGlobs'
    s.version = '1.0.0.LOCAL'
  
    s.authors = %w[Square]
    s.homepage = 'https://github.com/Square/cocoapods-generate'
    s.source = { git: 'https://github.com/Square/cocoapods-generate' }
    s.summary = 'Testing pod'
  
    s.swift_versions = %w[5.2]
    s.ios.deployment_target = '9.0'
  
    s.source_files = 'Sources/**/*.{h,m,swift}'
    s.private_header_files = 'Sources/Internal/**/*.h'

    s.source_files = "Sources/**/*.[mh]", "SourcesThatDontExist/*"
    s.public_header_files = "Sources/Public/*.h"
    s.private_header_files = "Sources/Private/*.h"

    s.app_spec 'App' do |app_spec|
        app_spec.source_files = 'App/main.swift'
    end
end

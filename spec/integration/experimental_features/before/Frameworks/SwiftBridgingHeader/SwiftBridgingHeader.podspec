# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name = 'SwiftBridgingHeader'
  s.version = '1.0.0.LOCAL'

  s.authors = %w[Square]
  s.homepage = 'https://github.com/Square/cocoapods-generate'
  s.source = { git: 'https://github.com/Square/cocoapods-generate' }
  s.summary = 'Testing pod'

  s.swift_versions = %w[5.2]
  s.ios.deployment_target = '9.0'

  s.source_files = 'Sources/**/*.{h,m,swift}'

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.{h,m,swift}'
    ts.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '${PODS_TARGET_SRCROOT}/Tests/BridgingHeader.h',
    }
  end

  s.app_spec 'App' do |as|
    as.source_files = 'App/**/*.{h,swift}'
    as.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '${PODS_TARGET_SRCROOT}/App/BridgingHeader.h',
    }
  end
end

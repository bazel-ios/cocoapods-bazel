# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name = 'A'
  s.version = '1.0.0.LOCAL'

  s.authors = %w[Square]
  s.homepage = 'https://github.com/Square/cocoapods-generate'
  s.source = { git: 'https://github.com/Square/cocoapods-generate' }
  s.summary = 'Testing pod'

  s.swift_versions = %w[5.2]
  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/**/*.{h,m,swift}'
  s.private_header_files = 'Sources/Internal/**/*.h'

  s.info_plist = {
    'CFBundleShortVersionString' => '1.0.0'
  }

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.{m,swift}'
  end

  s.app_spec 'App' do |as|
    as.source_files = 'App/**/*.swift'

    as.pod_target_xcconfig = {
      'ARCHS' => 'arm64 x86',
      'HEADER_SEARCH_PATHS'=> "${PODS_ROOT}/Headers/Private",
      'OTHER_CFLAGS' => '-Wno-conversion -Wno-error=at-protocol',
      'OTHER_LDFLAGS' => '-all_load',
      'OTHER_SWIFT_FLAGS' => '-DDEBUG',
      'VERSIONING_SYSTEM' => 'apple-generic',
      'SWIFT_OPTIMIZATION_LEVEL' => "$(SWIFT_OPTIMIZATION_LEVEL_$(CONFIGURATION))",
      'SWIFT_OPTIMIZATION_LEVEL_Debug' => '-Onone',
      'SWIFT_OPTIMIZATION_LEVEL_Release' => '-Owholemodule'
    }
  end
end

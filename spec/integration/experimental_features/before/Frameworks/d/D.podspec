# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name = 'D'
  s.version = '1.0.0.LOCAL'

  s.authors = %w[Square]
  s.homepage = 'https://github.com/Square/cocoapods-generate'
  s.source = { git: 'https://github.com/Square/cocoapods-generate' }
  s.summary = 'Testing pod'

  s.swift_versions = %w[5.2]
  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/**/*.{h,m,swift}'
  s.private_header_files = 'Sources/Internal/**/*.h'

  s.dependency 'A'
  s.dependency 'C'
  s.dependency 'Public'

  s.test_spec 'Tests' do |ts|
    ts.requires_app_host = true
    ts.app_host_name = 'D/App'
    ts.dependency 'D/App'

    ts.source_files = 'Tests/**/*.{m,swift}'

    ts.dependency 'E'

    ts.info_plist = {
      'COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY' => true,
      'COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY_2' => 'KEY_2',
    }
  end

  s.app_spec 'App' do |as|
    as.source_files = 'App/**/*.swift'

    as.pod_target_xcconfig = {
      'TARGETED_DEVICE_FAMILY' => '2',
      'SWIFT_PLATFORM_TARGET_PREFIX' => 'ios',
      'SWIFT_DEPLOYMENT_TARGET' => '9.0',
      'LLVM_TARGET_TRIPLE_OS_VERSION' => 'ios9.0'
    }

    as.info_plist = {
      'COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY' => true,
      'COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY_2' => 'KEY_2',
    }
  end
end

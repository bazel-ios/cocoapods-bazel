# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name = 'B'
  s.version = '1.0.0.LOCAL'

  s.authors = %w[Square]
  s.homepage = 'https://github.com/Square/cocoapods-generate'
  s.source = { git: 'https://github.com/Square/cocoapods-generate' }
  s.summary = 'Testing pod'

  s.ios.deployment_target = '11.0'
  s.swift_versions = %w[5.2]

  s.source_files = 'Sources/**/*.{h,m,swift}'
  s.private_header_files = 'Sources/Internal/**/*.h'

  s.dependency 'A'

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.{h,m,swift}'
    ts.pod_target_xcconfig = {
      'PRODUCT_BUNDLE_IDENTIFIER' => '$(PRODUCT_BUNDLE_IDENTIFIER_$(CONFIGURATION))',
      'PRODUCT_BUNDLE_IDENTIFIER_Debug' => 'org.cocoapods.B-Test.Debug',
      'PRODUCT_BUNDLE_IDENTIFIER_Release' => 'org.cocoapods.B-Test'
    }
  end

  s.app_spec 'App' do |as|
    as.source_files = 'App/**/*.{h,m,swift}'
    as.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(HEADER_SEARCH_PATHS_$(CONFIGURATION))',
      'HEADER_SEARCH_PATHS_Debug' => '${PODS_ROOT}/Headers/Private/Debug',
      'HEADER_SEARCH_PATHS_Release' => '${PODS_ROOT}/Headers/Private/Release',
      'INFOPLIST_FILE' => '$(INFOPLIST_FILE_$(CONFIGURATION))',
      'INFOPLIST_FILE_Debug' => 'Resources/debug.plist',
      'INFOPLIST_FILE_Release' => 'Resources/release.plist',
      'OTHER_CFLAGS' => '-Wno-conversion -Wno-error=at-protocol',
      'CODE_SIGN_ENTITLEMENTS' => '$(CODE_SIGN_ENTITLEMENTS_$(CONFIGURATION))',
      'CODE_SIGN_ENTITLEMENTS_Debug' => '$(PODS_TARGET_SRCROOT)/Resources/debug.entitlements',
      'CODE_SIGN_ENTITLEMENTS_Release' => '$(PODS_TARGET_SRCROOT)/Resources/release.entitlements',
      'PRODUCT_BUNDLE_IDENTIFIER' => '$(PRODUCT_BUNDLE_IDENTIFIER_$(CONFIGURATION))',
      'PRODUCT_BUNDLE_IDENTIFIER_Debug' => 'org.cocoapods.B-App.Debug',
      'PRODUCT_BUNDLE_IDENTIFIER_Release' => 'org.cocoapods.B-App'
    }
  end


  s.app_spec 'DebuggableOnlyApp' do |as|
    as.source_files = 'App/**/*.{h,m,swift}'
    as.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(HEADER_SEARCH_PATHS_$(CONFIGURATION))',
      'HEADER_SEARCH_PATHS_Debug' => '${PODS_ROOT}/Headers/Private/Debug',
      'HEADER_SEARCH_PATHS_Release' => '${PODS_ROOT}/Headers/Private/Release',
      'INFOPLIST_FILE' => '$(INFOPLIST_FILE_$(CONFIGURATION))',
      'INFOPLIST_FILE_Debug' => 'Resources/debug.plist',
      'INFOPLIST_FILE_Release' => 'Resources/release.plist',
      'OTHER_CFLAGS' => '-Wno-conversion -Wno-error=at-protocol',
      'CODE_SIGN_ENTITLEMENTS' => '$(CODE_SIGN_ENTITLEMENTS_$(CONFIGURATION))',
      'CODE_SIGN_ENTITLEMENTS_Debug' => '$(PODS_TARGET_SRCROOT)/Resources/debug.entitlements',
      'PRODUCT_BUNDLE_IDENTIFIER' => '$(PRODUCT_BUNDLE_IDENTIFIER_$(CONFIGURATION))',
      'PRODUCT_BUNDLE_IDENTIFIER_Debug' => 'org.cocoapods.B-DebuggableOnlyApp.Debug',
      'PRODUCT_BUNDLE_IDENTIFIER_Release' => 'org.cocoapods.B-DebuggableOnlyApp'
    }
  end  
end

# frozen_string_literal: true

Pod::Spec.new do |s|
    s.name = 'GlobExpansion'
    s.version = '1.0.0.LOCAL'
  
    s.authors = %w[Rules-iOS]
    s.homepage = 'https://github.com/bazel-ios/cocoapods-bazel'
    s.source = { git: 'https://github.com/bazel-ios/cocoapods-bazel' }
    s.summary = 'foo'
  
    s.swift_versions = %w[5.2]
    s.ios.deployment_target = '9.0'
  
    s.ios.resource_bundle = { 
        'ShouldExpand' => [
            'Resources/Localization/*.lproj', 
            'Resources/Images.xcassets',
            'Resources/*.xcdatamodeld',
        ],
        'ShouldNotExpand' => [
            'Resources/*.xib', 
            'Resources/*.strings',
            'Resources/*.png',
            'Resources/*.otf',
            'Resources/*.storyboard',
            'Resources/**/*',
        ],
        'Composite' => [
            'Resources/*.{strings,json}', 
            'Resources/*.{lproj,storyboard,xcassets,xib}',
        ]
    }
end

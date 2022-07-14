Pod::Spec.new do |s|
  s.name                    = 'FirebaseRemoteConfigSwift'
  s.version                 = '9.2.0'
  s.summary                 = 'Swift Extensions for Firebase Remote Config'

  s.description      = <<-DESC
Firebase Remote Config is a cloud service that lets you change the
appearance and behavior of your app without requiring users to download an
app update.
                       DESC


  s.homepage                = 'https://developers.google.com/'
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'

  ios_deployment_target = '10.0'

  s.ios.deployment_target = ios_deployment_target

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseRemoteConfigSwift/Sources/*.swift',
  ]

  s.dependency 'FirebaseRemoteConfig', '~> 9.0'
end

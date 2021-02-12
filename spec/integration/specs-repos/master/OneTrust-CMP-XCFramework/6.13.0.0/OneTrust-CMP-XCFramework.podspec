# frozen_string_literal: true

Pod::Spec.new do |s|
    s.name = 'OneTrust-CMP-XCFramework'
    s.version = '6.13.0.0'  
    s.summary = "OneTrust Publishers native SDK for iOS Applications"
    s.description = "'OneTrust SDK for managing user consents under GDPR, CCPA, and other privacy regulations. This SDK supports iOS devices, operates natively, and is IAB TCF 2.0 compliant.'"
    s.homepage = "https://www.onetrust.com/"
    s.license = {
        "type": "Commercial",
        "text": "The license and use of the OneTrust SDK is subject to the license terms at https://onetrust.com/terms/v20190401OneTrustTermsCloud.pdf. Alternatively, if a separately executed agreement exists between your organisation and OneTrust for the license of OneTrust software, such agreement shall govern the license and use of the OneTrust SDK. The right to use the OneTrust SDK is subject to your organisation having a current subscription for the OneTrust Mobile App Scanning and Consent module.\n"
    }
    s.authors = {
        "OneTrust, LLC.": "support@onetrust.com"
    }
    s.source = {
        "http": "file://#{File.expand_path '../../../../OneTrust-CMP-XCFramework-6.13.0.zip', __dir__}"
    }
    s.ios.deployment_target = '11.0'
    s.ios.vendored_frameworks = "OTPublishersHeadlessSDK.xcframework"
    s.swift_versions = %w[5.1]
  end

# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name = 'Public'
  s.version = '3.0.0'

  s.source = { http: "file://#{File.expand_path '../../../../pod.tar', __dir__}" }

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS'=> "${PODS_ROOT}/Headers/Private",
    'OTHER_CFLAGS' => '-Wno-conversion -Wno-error=at-protocol',
    'OTHER_LDFLAGS' => '-all_load',
    'OTHER_SWIFT_FLAGS' => '-DDEBUG',
  }
end

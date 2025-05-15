# frozen_string_literal: true

RSpec.describe Pod::Bazel::XCConfigResolver do
  it 'resolves empty xcconfigs' do
    default_config_name, resolved = described_class.resolve_xcconfig({})
    expect(default_config_name).to be_nil
    expect(resolved).to eq({})
  end

  it 'resolves xcconfigs' do
    default_config_name, resolved = described_class.resolve_xcconfig(
      {
        'ENABLE_TESTABILITY_Debug' => 'YES',
        'ENABLE_TESTABILITY_Release' => 'NO',
        'ENABLE_TESTABILITY' => '$(ENABLE_TESTABILITY_$(CONFIGURATION))',

        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) foo bar=1 "baz=${ENABLE_TESTABILITY}"',

        'CONFIGURATION' => 'Debug'
      }
    )
    expect(default_config_name).to be_nil
    expect(resolved).to eq(
      'ENABLE_TESTABILITY' => 'YES',
      'ENABLE_TESTABILITY_Debug' => 'YES',
      'ENABLE_TESTABILITY_Release' => 'NO',

      'GCC_PREPROCESSOR_DEFINITIONS' => ['foo', 'bar=1', 'baz=YES']
    )
  end
end

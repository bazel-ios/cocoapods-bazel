# frozen_string_literal: true

RSpec.describe Pod::Bazel::Util do
  it 'sorts Bazel labels as expected' do
    mixed_bazel_labels = [
      'Last',
      '@Third:Test',
      '//ProjectRoot/Project/AppProjectSDK/Wiring:AppProjectSDKWiring',
      '//ProjectRoot/Project/AppProjectSetupHelp',
      '//ProjectRoot/Project/SharedUtilities',
      '//ProjectRoot/Project/SharedUtilities/Wiring:SharedUtilitiesWiring',
      '//ProjectRoot/Project/StandardApis',
      'Last:SuperLast',
      '//ProjectRoot/Project/AppProjectSetupHelp/FakeTest:AppProjectSetupHelpFakeTest',
      '//ProjectRoot/Project/AppProjectSetupHelp:AppProjectSetupHelpFake',
      '//ProjectRoot/Project/AppProjectSDK',
      ':First',
      '@Third',
      ':First/First:Second'
    ]

    expected = [
      ':First',
      ':First/First:Second',
      '//ProjectRoot/Project/AppProjectSDK',
      '//ProjectRoot/Project/AppProjectSDK/Wiring:AppProjectSDKWiring',
      '//ProjectRoot/Project/AppProjectSetupHelp',
      '//ProjectRoot/Project/AppProjectSetupHelp:AppProjectSetupHelpFake',
      '//ProjectRoot/Project/AppProjectSetupHelp/FakeTest:AppProjectSetupHelpFakeTest',
      '//ProjectRoot/Project/SharedUtilities',
      '//ProjectRoot/Project/SharedUtilities/Wiring:SharedUtilitiesWiring',
      '//ProjectRoot/Project/StandardApis',
      '@Third',
      '@Third:Test',
      'Last',
      'Last:SuperLast'
    ]

    sorted = Pod::Bazel::Util.sort_labels(mixed_bazel_labels)
    expect(sorted).to eq(expected)
  end
end

RSpec.describe Pod::Bazel::Util::SortKey do
  describe 'SortKey .initialize' do
    it 'returns a sort key object' do
      key = Pod::Bazel::Util::SortKey.new('not a Bazel label', 0)
      expect(key).to_not be_nil
    end

    it 'assigns the correct phase to Bazel labels' do
      key = Pod::Bazel::Util::SortKey.new(':Something', 0)
      expect(key.phase).to eq(1)

      key = Pod::Bazel::Util::SortKey.new('//Something', 0)
      expect(key.phase).to eq(2)

      key = Pod::Bazel::Util::SortKey.new('@Something', 0)
      expect(key.phase).to eq(3)

      key = Pod::Bazel::Util::SortKey.new('Regular Something', 0)
      expect(key.phase).to eq(4)
    end
  end
end

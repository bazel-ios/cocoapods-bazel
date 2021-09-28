import XCTest

class InfoPlistTests: XCTestCase {
  func test_testPlist() {
      let infoDictionary = Bundle(for: InfoPlistTests.self).infoDictionary!
      XCTAssertEqual(infoDictionary["COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY"] as? Bool, true)
      XCTAssertEqual(infoDictionary["COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY_2"] as? String, "KEY_2")
  }

  func test_appPlist() {
      let infoDictionary = Bundle.main.infoDictionary!
      XCTAssertEqual(infoDictionary["COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY"] as? Bool, true)
      XCTAssertEqual(infoDictionary["COCOAPODS_BAZEL_TEST_INFO_PLIST_KEY_2"] as? String, "KEY_2")
  }
}

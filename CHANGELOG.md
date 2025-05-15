0.1.7
* Adding `testonly` to targets that link with XCTest becomes an opt-in with config `enable_add_testonly`

0.1.6
* New xcframework_excluded_platforms option
* Add .ruby-version file, update github action code

0.1.5
* Add `testonly` to targets that link with XCTest to account for requirements in https://github.com/bazelbuild/rules_swift/pull/868 (#82)
 
0.1.4

* Fix issues with glob evaluation (#64, #65)
* Get specs running on M1 hardware (#73)
* Expose CocoaPods environment variables PODS_ROOT and PODS_TARGET_SRCROOT (#67)
* Mark app specs with public visibility for usage as test apps (#77)
* README updates for buildifier option and link fixing (#69, #78)
* Remove non-existent globs to support using --incompatible_disallow_empty_glob (#80, #79)

0.1.3

* Add ability to insert a docstring at top of generated build files (#58)
* Remove expand_directories for resource_bundle (#48)

0.1.2

* Generate empty BUILD.bazel file at sandbox root (Pods/) during build file generation stage

0.1.1

* Raise error and offer suggestion if pod path is outside of current workspace

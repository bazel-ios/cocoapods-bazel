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

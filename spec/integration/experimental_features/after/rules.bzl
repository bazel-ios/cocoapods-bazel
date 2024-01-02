load("@build_bazel_rules_ios//rules:app.bzl", _ios_application = "ios_application")
load("@build_bazel_rules_ios//rules:framework.bzl", _apple_framework = "apple_framework")
load("@build_bazel_rules_ios//rules:test.bzl", _ios_unit_test = "ios_unit_test")

EXPERIMENTAL_DEPS_SUFFIX = ".lib"

def apple_framework(**kwargs):
    module_name = kwargs.pop("module_name", None) or kwargs.get("name")
    name = kwargs.pop("name") + EXPERIMENTAL_DEPS_SUFFIX
    _apple_framework(
        name = name,
        module_name = module_name,
        **kwargs,
    )

def ios_application(**kwargs):
    module_name = kwargs.pop("module_name", None) or kwargs.get("name")
    name = kwargs.pop("name") + EXPERIMENTAL_DEPS_SUFFIX
    _ios_application(
        name = name,
        module_name = module_name,
        **kwargs,
    )

def ios_unit_test(**kwargs):
    module_name = kwargs.pop("module_name", None) or kwargs.get("name")
    name = kwargs.pop("name") + EXPERIMENTAL_DEPS_SUFFIX
    _ios_unit_test(
        name = name,
        module_name = module_name,
        **kwargs,
    )

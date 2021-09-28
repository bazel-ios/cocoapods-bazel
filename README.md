# Cocoapods::Bazel
![](https://github.com/ob/cocoapods-bazel/workflows/master/badge.svg)


Cocoapods::Bazel is a Cocoapods plugin that makes it easy to use [Bazel](https://bazel.build) instead of Xcode to build your iOS project. It automatically generates Bazel's `BUILD.bazel` files. It uses [`rules_ios`](https://github.com/ob/rules_ios) so you need to set up the `WORKSPACE` file following the instructions in the [`README`](https://github.com/ob/rules_ios/blob/master/README.md).

> :warning: **This is alpha software.** We are developing this plugin in the open so you should only use it if you know what you are doing and are willing to help develop it.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cocoapods-bazel'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cocoapods-bazel

## Usage

This plugin will run extra steps after post_install to generate BUILD.bazel files for Bazel.

To enable the plugin, simply add the following section to your `Podfile`

```
plugin 'cocoapods-bazel', {
  rules: {
    'apple_framework' => { load: '@build_bazel_rules_ios//rules:framework.bzl', rule: 'apple_framework' }.freeze,
    'ios_application' => { load: '@build_bazel_rules_ios//rules:app.bzl', rule: 'ios_application' }.freeze,
    'ios_unit_test' => { load: '@build_bazel_rules_ios//rules:test.bzl', rule: 'ios_unit_test' }.freeze
  }.freeze,
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Experimental Features

There are some experimental features that are opt-in and can be enabled adding the plugin to the `Podfile`. Some of these features intentionally break the contract with the `.podspecs` specification in order to create `BUILD` files that are easier to maintain and/or evolve using Bazel features that don't have a direct relationship with what cocoapods does. You'll find the keys to enable such features and a brief explanation/motivation for each in `Bazel::Config::EXPERIMENTAL_FEATURES` (`lib/cocoapods/bazel/config.rb`).

Note that tests for the experimental features are located under `spec/integration/experimental_features` and these should mostly replicate the tests under `spec/integration/monorepo` but with the features on. Also it's a place to create tests specific to a experimental feature that not necessarily will affect the default usage of `cocoapods-bazel`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ob/cocoapods-bazel.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

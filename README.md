# Discord Fork: Cocoapods::Bazel

This is our Discord-specific fork of [Cocoapods-Bazel](https://github.com/bazel-ios/cocoapods-bazel).

- We use the `discord` branch as our main branch, the `master` branch should mirror `master` from upstream.

## Local development against the monorepo
You can configure your iOS builds in the [monorepo](https://github.com/discord/discord) to use a local checkout of this
repository for local development:

1. Open `discord_ios/Gemfile` in your monorepo checkout.
2. Comment out the existing cocoapods-bazel gem line and add a new one below:
   ```rb
   # gem 'cocoapods-bazel', :github => 'discord/cocoapods-bazel', :ref => '722c9398ac628943e4084eaebfcec0e85f536663'
   gem 'cocoapods-bazel', path: '/path/to/cocoapods-bazel'
   ```
3. Open an iOS Nix shell and run `bundle lock` to update `Gemfile.lock`:
   ```sh
   $ clyde nix shell -A iosShell
   $ cd discord_ios
   $ bundle lock
   ```
4. Don't forget to revert the changes to `Gemfile` and `Gemfile.lock` before making your PR!

## Updating the monorepo after merging a PR
After merging a PR to this repository, you must update the monorepo to point to the new commit:

1. Copy the latest commit hash that the `discord` branch is pointing to after you landed your PR.
2. Open `discord_ios/Gemfile` in your monorepo checkout.
3. Update the `:ref` attribute for the `cocoapods-bazel` gem to the new hash:
   ```rb
   gem 'cocoapods-bazel', :github => 'discord/cocoapods-bazel', :ref => '[NEW COMMIT HASH GOES HERE]'
   ```
4. Open an iOS Nix shell and run `bundle lock` to update `Gemfile.lock`:
   ```sh
   $ clyde nix shell -A iosShell
   $ cd discord_ios
   $ bundle lock
   ```
5. Verify `clyde ios sync-pods` and an iOS build still works, and commit your changes.

# Cocoapods::Bazel
![](https://github.com/ob/cocoapods-bazel/workflows/master/badge.svg)


Cocoapods::Bazel is a Cocoapods plugin that makes it easy to use [Bazel](https://bazel.build) instead of Xcode to build your iOS project. It automatically generates Bazel's `BUILD` files.

`cocoapods-bazel` can be setup to translate CocoaPod targets to provided Bazel rules. For example, you can use `cocaopods-bazel` to load framework targets using [rules_ios](https://github.com/bazel-ios/rules_ios). It's also flexible enough to allow users to use their own custom rules if needed.

> :warning: **This is alpha software.** We are developing this plugin in the open so you should only use it if you know what you are doing and are willing to help develop it.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cocoapods-bazel'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install cocoapods-bazel
```

## Usage

This plugin will run extra steps after post_install to generate `BUILD` files for Bazel.

To enable the plugin, you can add something like the following section to your `Podfile`:

```ruby
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

## BUILD file formatting

When the `BUILD.bazel` files are generated you may choose to have `cocoapods-bazel` format the files using [buildifier](https://github.com/bazelbuild/buildtools/blob/master/buildifier/README.md). This formatting is enabled by default if a `buildifier` executable is found using `which buildifier`.

You can disable buildifier formatting with `buildifier: false` in the options of the `cocoapods-bazel` plugin.

Additionally, if you'd like to use a custom `buildifier` executable you can provide the `cocoapods-bazel` plugin options with an array of arguments to execute to format files.

For example, if you have `buildifier` runnable target you've defined in Bazel with the name `buildifier` you can run this specific version with: `buildifier: ['bazel', 'run', 'buildifier', '--']`. (Note the `--` allows bazel to forward arguments to the buildifier target).

## Contributing

Bug reports and pull requests are welcome on GitHub [here](https://github.com/bazel-ios/cocoapods-bazel).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

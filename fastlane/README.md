fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac certificates

```sh
[bundle exec] fastlane mac certificates
```

Install the Developer ID certificate from the match repo

### mac test

```sh
[bundle exec] fastlane mac test
```

Run the unit tests

### mac build

```sh
[bundle exec] fastlane mac build
```

Archive and export a Developer ID–signed OpenProcess.app into build/

### mac dmg

```sh
[bundle exec] fastlane mac dmg
```

Package the already-built app into a DMG, without notarizing

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, notarize and package the DMG that ships on GitHub

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

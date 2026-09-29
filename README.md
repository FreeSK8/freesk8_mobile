# freesk8_mobile

A Flutter project to enhance connectivity to your ESK8 or PEV.

This project also serves as a companion application to the [FreeSK8 Robogotchi](https://derelictrobot.com/collections/production/products/freesk8-robogotchi).

## Download / Releases

Android APKs are published on the [GitHub Releases page](https://github.com/FreeSK8/freesk8_mobile/releases)
(the [latest release](https://github.com/FreeSK8/freesk8_mobile/releases/latest) is always the current
version). Each release carries the APK and its SHA-256 checksum. A release marked **pre-release** is
either a release candidate (tag with a `-rc` suffix) or a debug-signed test build; a debug-signed build
cannot be upgraded in place by a later signed release, so uninstall it first.

iOS builds are not distributed through GitHub Releases.

## Supported ESC firmware

| VESC firmware | Motor and app configuration |
| --- | --- |
| 5.1, 5.2, 5.3 | read and write |
| 6.00, 6.02 | read and write |
| 6.05, 6.06 | read and write |
| 7.00 | read and write (an unknown 7.x minor is tried with the 7.00 layout) |

Other versions are reported as unsupported and the Motor and Input configuration screens are disabled
for them. The configuration serializers are generated from the firmware's own sources; see
[`tool/esc_serializers/SOURCES.md`](tool/esc_serializers/SOURCES.md) for how a new release is added.

## Building from source

The Flutter version is pinned in `pubspec.yaml` (`environment.flutter`); `flutter pub get` refuses any
other version, so install exactly that one (for example with [fvm](https://fvm.app) or
`git clone -b <version> https://github.com/flutter/flutter.git`). Then:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # Android; see CI_GUIDE.md for release signing
```

## Release process

1. Bump `version:` in `pubspec.yaml`, `freeSK8ApplicationVersion` in `lib/main.dart` (a unit test keeps
   them in sync) and add a `CHANGELOG` entry, in the pull request that finishes the version.
2. After the merge to `master`, tag the merge commit `v<version>` and push the tag. CI builds the APK,
   checks the tag against the pubspec version and publishes the GitHub Release with the CHANGELOG
   section as its notes. `v<version>-rc1` style tags publish a pre-release.

See [`CI_GUIDE.md`](CI_GUIDE.md) for the workflow details and the one-time signing setup.

## Getting Started

This project was a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view their
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Ok, for reals

This was my first flutter project and introduction to mobile app development. Code was produced
quickly, best practices were not always known and many lessons were learned the hard way.

The current structure of the application follows. Hopefully it is of some assistance as you
navigate the sources.

```
/lib
|
├ /components
|   └ Classes to support the main application
├ /hardwareSupport
|   └ Classes to support hardware components like VESC, FlexiBMS and DieBieMS
├ /mainViews
|   └ The four main tabs of the application
|       └ connectionStatus
|       |   └ Connect to BLE devices and display Robogotchi status
|       └ realTimeData
|       |   └ Real time ESC telemetry
|       |   └ Real time smart BMS telemetry
|       └ esk8Configuration
|       |   └ FreeSK8 Application Settings
|       |   └ ESC Speed Profiles
|       |   └ ESC Application Configuration (Input setup)
|       |   └ ESC Motor Configuration
|       └ rideLogging
|            └ Display rides logged in calendar or list view
├ /subViews
|   └ Full screen views that overlay the main application
|       └ escProfileEditor
|       └ focWizard
|       └ rideLogViewer
|       └ robogotchiCfgEditor (aka Logging Config Editor)
|       └ robogotchiDFU
└ /widgets
    └ Custom widgets that are used in the application
```

<!-- LICENSE -->
## License

(C) Copyright 2020-2024+ - Derelict Robot Industries & FreeSK8 Foundation

**Licensed under GNU General Public License v3.0**

<!-- CONTACT -->
## Authors

* Renee Glinski - [@r3n33](https://github.com/r3n33)
* Andrew Dresner - [@DerelictRobot](https://github.com/DerelictRobot)
* Project Link: [https://github.com/FreeSK8](https://github.com/FreeSK8)

 <!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


<!-- ACKNOWLEDGEMENTS -->
## Attribution & References

* [VESC-Project](https://vesc-project.com)
* [Flutter Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
* [Flutter Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)
* [pub.dev](https://pub.dev/)

# FreeSK8 Mobile — Modernization Context & Handoff

> Living handoff document for agents/developers working on the modernized app.
> Last updated: 2026-09-28 (v0.24.0 preparation, branch `test/inspiring-darwin-m43on1`).
>
> **STATUS:** Flutter **3.47.5 / Dart 3.13.4**, sound null safety, `flutter analyze` 0 errors,
> analyzer warnings fatal in CI, unit tests green, release APK builds locally and in CI.
> Tag-driven GitHub Releases are in place (see §8). Remaining work is listed in §7.

---

## 1. Project snapshot

- **App:** FreeSK8 Mobile — companion app for VESC-based vehicles + Robogotchi/gotchiPro telemetry
  logger. BLE (Nordic UART service) is the core transport; telemetry, config editors, file sync and
  OTA sit on top of it.
- **Toolchain:** Flutter 3.47.5 pinned in `pubspec.yaml` (`environment.flutter`); Android Gradle
  8.14.3 / AGP 8.13.2 / Kotlin 2.2.21 / compileSdk + targetSdk 36 / Java 17; iOS deployment
  target 15.0 (project files aligned with the 3.47 template, unverified on a Mac).
- **State management:** `setState` in `lib/main.dart` (the ~3,200-line `MyHomeState` God widget)
  plus a partial flutter_bloc layer (§9).

## 2. Branch map

| Branch | Contents |
|---|---|
| `master` | Flutter 3 / Dart 3 modernization (PR #34, 2026-07) |
| `test/inspiring-darwin-m43on1` | This work: latest Flutter/Dart, dependency updates, bug fixes, tag-driven releases, iOS template alignment, v0.24.0 |
| `0.23.0_ios` | Superseded. Its one real fix (ESC hardware-name decoding) is ported; iOS version bumps are obsolete |
| `0.2x.y`, `flutter-3.41-dart-3.11`, `flutter-bloc-state-engine`, `firebase_bringup`, `claude/update-flutter-dart-pfN82`, `cursor/setup-ci-*` | Fully merged or empty; safe to delete |

## 3. Work completed on this branch (chronological)

1. **Flutter 3.47.5 pin** + Dart 3.13 fixes (`var` parameter types); CI reads the version from pubspec.
2. **CI rewrite** (`.github/workflows/android-release.yml`): build on master, GitHub Release on `v*`
   tags, hardened signing, version-named artifacts, tag/pubspec/main.dart version guards.
3. **Runtime bug fixes:** DFU/OTA screens crashed on open (`FlutterBluePlus.scan()` throws in 2.x);
   backup export zip was empty (un-awaited archive 4 encoder); ESC hardware name decoding (from
   `0.23.0_ios`); unsupported-firmware detection restored via `MCCONF.isValid` / `APPCONF.isValid`.
4. **Tests** (`test/`): blocs + data models, hardware name, backup archive, config signature
   round-trips, version constant guard, equatable identity guard, debug log buffer.
5. **iOS project** aligned with the 3.47 template (iOS 15, versions from pubspec, Podfile,
   AppDelegate, xcconfig, Xcode Cloud script; `Podfile.lock` removed pending a Mac `pod install`).
6. **Android toolchain:** Gradle 8.14.3, AGP 8.13.2, Kotlin 2.2.21 (Flutter 3.47 minimums are
   Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20); targetSdk 36; manifest cleanup (§6).
7. **Deprecation cleanup:** PopScope, WidgetState, withValues, textScaler, RadioGroup, launchUrl,
   flutter_blue_plus remoteId/platformName, logger `.f()`, dead code removed.
8. **Dependencies:** unused packages removed; transitive-only imports declared; minor bumps;
   majors nordic_dfu 8, flutter_map 8 and wifi_iot 0.4 (§5); `flutter_lints` + `analysis_options.yaml`.
9. **Debug log console restored** (`lib/widgets/debugLog/`): `logger` ring buffer, viewer with
   filter/search/share, shake detection via `sensors_plus`; `logger_flutter` stub, override and
   git dependency deleted.
10. **Version 0.24.0+52**, CHANGELOG back-filled for 0.22.0–0.24.0, README release section,
    `CI_GUIDE.md` rewritten.
11. **ESC firmware support** (§11): motor/app configuration serializers generated from vendored VESC
    firmware sources for 5.1, 5.2, 5.3, 6.00/6.02, 6.05, 6.06 and 7.00 (the hand-written 6.x
    serializers were misaligned); tolerant enum and fault-code decoding; `FirmwareFeatures` drives
    the motor and input editors (regen cutoff, BMS cell voltage limits, offsets calibration, ADC
    button bitmask, balance app hidden on 6.05+); CI checks that the generated files are current.

## 4. Environment learnings (read before you start)

- **No Flutter SDK in the container.** Download
  `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_<VER>-stable.tar.xz`
  (~1 GB), extract to scratch, `export BOT=true`, `git config --global --add safe.directory <sdk>`.
  `flutter pub get` works through the session proxy.
- **Android SDK:** command-line tools zip from `dl.google.com` + `sdkmanager "platform-tools"
  "platforms;android-36" "build-tools;36.0.0"`, then `flutter config --android-sdk`.
- **Stale plugin build output can break a plugin major bump:** all plugins build under
  `build/<plugin>/`; after nordic_dfu 6 -> 8 the Kotlin incremental cache produced bogus
  "unresolved reference" errors until `rm -rf build/nordic_dfu`. Clean the plugin dir (or
  `flutter clean`) after changing a native plugin's major version.
- **Gradle wrapper download is proxy-blocked** (services.gradle.org redirects are refused).
  Pre-seed `~/.gradle/wrapper/dists/gradle-<V>-all/<hash>/gradle-<V>-all.zip` from
  `https://mirrors.cloud.tencent.com/gradle/`; `<hash>` is base-36 of the MD5 of the
  distributionUrl string (see the wrapper's PathAssembler). CI downloads normally.
- **Flutter 3.47 Gradle plugin enforces minimum Gradle/AGP/Kotlin versions** at plugin-apply time
  and already warns that Gradle < 9.1.0 and AGP < 9.0.1 support "will soon be dropped".
- Sessions are ephemeral; commit and push.

## 5. Dependencies: decisions and deferrals

- **nordic_dfu 8.x:** `startDfu(..., dfuEventHandler: DfuEventHandler(...))`; the plugin no longer
  declares Bluetooth permissions (the app manifest already does). Applies KGP itself on AGP < 9.
- **flutter_map 8.x:** no API changes were needed here; OSM tiles now use
  `https://tile.openstreetmap.org` with `userAgentPackageName`.
- **wifi_iot 0.4.0:** its Android sources are Java-only and it applies just `com.android.library`,
  so it builds on AGP 8.13 despite declaring an AGP 9.0.1 buildscript classpath (verified).
- **equatable 3 deferred:** 3.0 drops the runtimeType check, so bloc marker states sharing
  `props => []` would compare equal and `emit` would swallow transitions
  (`test/blocs_test.dart` has a guard). Give those states discriminating props first.
- **flutter_document_picker 5.2.3** is an AGP-3.6-era plugin; it builds only thanks to the
  namespace / JVM-11 shim in `android/build.gradle`. Replace it before the AGP 9 migration.
- Old packages that only resolve because Dart 3 relaxes their `<3.0.0` SDK cap:
  `multiselect_formfield`, `sliding_up_panel`.

## 6. Android notes

- `android/app/build.gradle`: compileSdk/targetSdk from the Flutter plugin (36), release signing
  from `android/key.properties` when present, debug signing otherwise.
- `android/build.gradle` keeps the compatibility shim (namespace from manifest `package`, Java and
  Kotlin JVM target 11) for unmaintained plugins.
- `android/gradle.properties` keeps `android.builtInKotlin=false` / `android.newDsl=false`; both
  opt-outs disappear with the AGP 9 migration (docs.flutter.dev "migrate-to-built-in-kotlin").
- Manifest: dead `background_locator` receivers/services and fake `READ_CONTENT`/`WRITE_CONTENT`
  permissions removed; `NormalTheme` added; debug/profile manifests are the template ones.

## 7. Remaining work / follow-ups

1. **On-device smoke test** (nothing here can exercise BLE): scan → connect → real-time telemetry →
   ride log sync → motor/app config read and write → Robogotchi DFU → backup export/import →
   shake-to-open debug console → external links. Include an ESC on firmware 6.05, 6.06 or 7.00:
   read the motor and app configuration, compare a few values with VESC Tool, write one harmless
   change (wheel diameter) and read it back; connect an unsupported version to see the
   "unsupported firmware" message instead of a crash.
2. **iOS on a Mac:** `flutter pub get && cd ios && pod install`, commit the regenerated
   `Podfile.lock`, build and run; then do the UIScene/SceneDelegate migration with Xcode.
3. **AGP 9 / Gradle 9.1+ / built-in Kotlin migration** (Flutter will drop AGP 8 / Gradle 8 support):
   replace `flutter_document_picker` first, remove the shim and the two opt-out flags, switch to the
   Kotlin DSL templates.
4. **equatable 3** (see §5).
5. **Bloc layer:** five blocs are provided but unused (§9); either wire them or delete them, and
   replace the `context.watch` at the top of `RealTimeData.build()` with scoped
   `BlocBuilder(buildWhen:)` so the 50 ms tick only redraws gauges.
6. **Release signing:** create the keystore and set the secrets + `HAS_SIGNING` (CI_GUIDE.md)
   before tagging a public release; without them releases are debug-signed pre-releases.
7. Dependabot alerts on master; `latlong2` 0.10; `package_info_plus` for the version string;
   `Logger` release-mode filter (`globalUtilities.dart` MyFilter TODO); `--split-per-abi` assets.

## 8. CI and releases

`.github/workflows/android-release.yml` (details in `CI_GUIDE.md`):
- push to `master` → build/analyze/test/APK → 30-day artifact
  `freesk8_mobile-<version>-g<sha>-<signed|debug-signed>`.
- push tag `vX.Y.Z` → same, then a GitHub Release with the APK + `.sha256`, the CHANGELOG section
  as body, generated notes; `vX.Y.Z-<suffix>` → pre-release.
- Guards: pubspec `version:` ↔ `lib/main.dart` `freeSK8ApplicationVersion` (also
  `test/version_test.dart`), tag ↔ pubspec version, signed APK when `HAS_SIGNING` is true.
- `flutter analyze --no-fatal-infos`: warnings fail CI, infos are advisory.

Release procedure: bump pubspec + main.dart + CHANGELOG in the PR → merge → tag the merge commit
`v<version>` → push the tag.

## 9. Bloc architecture reference

```
lib/blocs/
  preferences/    PreferencesCubit                       WIRED (realTimeData, rideLogging)
  telemetry/      TelemetryBloc                          PARTLY WIRED (main.dart 50 ms path; BMS still on a StreamController)
  location/       LocationBloc                           provided, not wired (main.dart owns GPS)
  ble_connection/ BLEConnectionBloc                      provided, not wired
  file_sync/      FileSyncBloc                           provided, not wired
  robogotchi/     RobogotchiBloc                         provided, not wired
  esc_config/     ESCConfigBloc                          provided, not wired
```
Conventions: Equatable events/states with `List<Object?> props`; never call `emit()` outside a
registered handler; `copyWith` uses nullable params + `??`.

Key UUIDs (UART service): `6e400001-…` service, `…0002` TX, `…0003` RX, `…0004` TX-logger,
`…0005` RX-logger (logger characteristics present ⇒ Robogotchi, else direct ESC).

## 10. Gotchas

- `ESCTelemetry`/`ESCFault` live in `hardwareSupport/escHelper/escHelper.dart`; `InputCalibration`
  in `subViews/inputConfigurationEditor.dart`; `TimeSeriesESC` at the bottom of `rideLogViewer.dart`.
- The firmware serializers (`hardwareSupport/escHelper/serialization/firmware*.dart`) are
  generated (§11); never edit them by hand. They return a default object on a signature mismatch;
  check `isValid`, never a field value.
- flutter_blue_plus 2.x: `FlutterBluePlus.scan()` throws; use `onScanResults` + `startScan()`.
  `connect()` requires `license:` (FreeSK8 uses `License.nonprofit`).
- archive 4.x: `ZipFileEncoder` add/close are async; use `createBackupArchive()`.
- Serialized MCCONF/APPCONF start with the signature at byte 0; the deserializers expect a
  packet-id byte first (index 1), see `test/esc_serializers_test.dart`.
- Font-size preference historical minimum is 14, not 10.
- Route tracking via phone GPS is intentionally disabled in `updateLocationForRoute`.

## 11. ESC firmware support

Supported: 5.1, 5.2, 5.3, 6.00, 6.02, 6.05, 6.06, 7.00 (`ESC_FIRMWARE` in
`lib/hardwareSupport/escHelper/escHelper.dart`; `ESCHelper.firmwareFor()` maps the reported
major/minor, an unknown 7.x minor falls back to the 7.00 layout and the signature check is the real
guard). Unknown versions map to `UNSUPPORTED`: telemetry still works, the Motor/Input configuration
menu entries refuse with a message and `main.dart` guards the configuration parsers.

- `tool/esc_serializers/generate.py` generates `serialization/firmware*.dart` and
  `tool/esc_serializers/layouts/*.json` from the vendored firmware sources in
  `tool/esc_serializers/vesc/<version>/`; `versions.json` maps versions to classes and renames
  fields; CI runs `generate.py --check`. Adding a release: `tool/esc_serializers/SOURCES.md`.
- `MCCONF`/`APPCONF` (`mcConf.dart`, `appConf.dart`) are the union of all versions. Enums are
  decoded through `serialization/wireEnums.dart` with per-version wire tables; an unknown index logs
  and falls back to the first member. Fault codes: `faultCodeFromWire` / `faultCodeName` in
  `dataTypes.dart`.
- `FirmwareFeatures(fw)` tells the editors what a release has: `hasBalanceApp`, `hasRegenCutoff`,
  `tempsAreWholeDegrees`, `hasBmsVoltageLimits`, `hasOffsetsCalOnBoot` / `hasOffsetsCalMode`,
  `adcButtonsBitmask`, `sensorModes`.
- Wire-format history: 6.0 replaced the ADC invert flags with the `app_adc_conf.buttons` bitmask
  (bit 0 enabled, bit 1 invert cruise control, bit 2 invert reverse); 6.05 removed
  `app_balance_conf` and `APP_BALANCE` (so `app_use` wire indices shift), made the temperature
  limits whole degrees and added the regen cutoff and BMS voltage limits; 6.06 replaced
  `foc_offsets_cal_on_boot` with the `foc_offsets_cal_mode` bitmask (bit 0 = on boot); 7.00 added
  `FOC_SENSOR_MODE_ENCODER_AB` and the nunchuk coast brake. The bldc `master` branch has the 7.00
  layout under a different signature and is not supported until it is released.
- Tests: `test/esc_serializers_test.dart` (per-version round trips, sizes, signatures and enum
  lists against the layout tables), `test/esc_firmware_detection_test.dart`.

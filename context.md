# FreeSK8 Mobile — Modernization Context & Handoff

> Living handoff document for agents/developers continuing the Flutter 3 / Dart 3
> modernization. Last updated: 2026-07-07. Branch: `claude/update-flutter-dart-pfN82`
> (identical history also exists on `flutter-bloc-state-engine`).

---

## 1. Project snapshot

- **App:** FreeSK8 Mobile — companion app for VESC-based skateboards + Robogotchi telemetry logger. BLE (UART service) is the core transport; everything else (telemetry, config editors, file sync, OTA) sits on top of it.
- **Original codebase:** Flutter 2.x era, pre-null-safety (Dart language 2.10), `setState()`-driven with ~60 state fields in one God-widget (`MyHomeState` in `lib/main.dart`, ~3,200 lines).
- **Target:** Latest stable Flutter (**3.44.5 / Dart 3.12.2** as of 2026-07-06 — verified from the official releases feed), sound null safety, flutter_bloc state management.

## 2. Branch map

| Branch | Contents |
|---|---|
| `master` | Untouched upstream (0.23.0, pre-null-safety) |
| `flutter-3.41-dart-3.11` | Dependency/API modernization + `CI_GUIDE.md` (superseded) |
| `flutter-bloc-state-engine` | + bloc foundation, null-safety declaration migration (superseded) |
| **`claude/update-flutter-dart-pfN82`** | **Current working branch — everything above + review fixes, CI workflow, this doc** |

## 3. Work completed (chronological)

1. **Dependency modernization** (`pubspec.yaml`): SDK `>=3.0.0 <4.0.0`; flutter_blue_plus v2, flutter_map v7, flutter_slidable v4, wakelock_plus, share_plus v13, community_charts_flutter, geolocator v14, etc.
2. **API migrations** in code: flutter_blue_plus v2 (static `FlutterBluePlus.*`, `remoteId`, `lastValueStream`, `BluetoothConnectionState`, required `license:` param on `connect()` — using `License.nonprofit`), flutter_map v7 (`children:`/`TileLayer`/`MarkerLayer`/`Marker(child:)`/`CameraFit.bounds`/`controller.camera.zoom`), share_plus v11+ API (`SharePlus.instance.share(ShareParams(...))`), image_picker (`pickImage`/`XFile`), archive (`archive_io.dart` for `ZipFileEncoder`).
3. **`CI_GUIDE.md`** — keystore + secrets setup guide for Android release CI.
4. **flutter_bloc foundation** (`lib/blocs/`, 21 files): `PreferencesCubit` (wired: realTimeData, rideLogging), `TelemetryBloc` (wired: 50 ms hot path routed through it, main.dart no longer `setState()`s per tick), `LocationBloc`, `BLEConnectionBloc`, `FileSyncBloc`, `RobogotchiBloc`, `ESCConfigBloc` (created + provided via `MultiBlocProvider`, **not yet wired** — main.dart still owns those subsystems).
5. **Null-safety declaration migration** (47 files): `@required`→`required`, uninitialized fields→`Type?`, `copyWith` params→nullable, Equatable `props`→`List<Object?>`.
6. **Review fixes (this session):** bloc layer now analyzer-clean (0 errors); all one-off structural errors fixed (see §6); `share_plus` bumped to ^13.2.0 to resolve a hard `win32` version conflict with wakelock_plus; CI workflow added (§8).

## 4. Environment learnings (read before you start)

- **No Flutter SDK in the container.** Install: download `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_<VER>-stable.tar.xz` (~1 GB, the proxy allows it), extract to scratch, then:
  - `export BOT=true` (suppresses the root-user prompt that otherwise hangs the tool)
  - `git config --global --add safe.directory <flutter-sdk-path>`
- **`flutter pub get` works** through the session proxy against pub.dev.
- **Sessions are ephemeral** — anything not committed and pushed is lost on container recycle. Remote branches survive.
- **latest-stable check:** `curl https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json` → `current_release.stable`.

## 5. Known blockers

### 5.1 `logger_flutter` (temporarily stubbed — needs real replacement)
The git dependency `FreeSK8/logger_flutter` is pre-null-safety and **hard-blocks dependency resolution** under Dart 3. Currently worked around via `pubspec_overrides.yaml` → `third_party/logger_flutter_stub/`, a null-safe stub whose `LogConsoleOnShake` just renders its child. **Consequence: shake-to-show-debug-log is non-functional.** Proper fix options (pick one):
- Vendor the real console UI: port `LogConsole`/`LogConsoleOnShake` from the fork into `lib/widgets/` (it's ~2 files; migrate to null safety while porting, drop `sensors` dependency or use `sensors_plus` for shake detection), then delete the stub + override + git dependency.
- Or migrate the `FreeSK8/logger_flutter` fork itself to null safety and repoint the git ref.

### 5.2 `flutter_nordic_dfu` (unverified at runtime)
Pinned to `fengqiangboy/flutter-nordic-dfu` git master. It resolves, but `lib/subViews/robogotchiDFU.dart` calls `FlutterNordicDfu.startDfu(...)` from the old 3.x API — newer versions renamed the entry point (`NordicDfu().startDfu`). Verify/migrate when touching DFU.

## 6. Comprehensive review — findings (2026-07-07)

Method: full `flutter analyze` on Flutter 3.44.5 (first time the analyzer has run on this branch), plus prior Opus 4.7 manual audit.

### Fixed during this review
- `lib/blocs/**` — **all 21 files now 0 analyzer errors**: `props` base signatures (`List<Object?>`), `LocationPermissionDenied` event/state name collision (event renamed `LocationPermissionDeniedEvent`), nullable args in `FileSyncBloc`/`TelemetryBloc`, required `license:` on `connect()`.
- `community_charts_flutter/flutter.dart` → `community_charts_flutter.dart` (bad URI, 2 files).
- Last `Marker(builder:)` in rideLogViewer.dart; last `_mapController.zoom` in brocator.dart.
- `AppLifecycleState.hidden` switch case (autoStopHandler.dart).
- `AndroidDeviceInfo.androidId` removed (device_info_plus dropped it; value was unused).
- `ImagePicker.getImage`→`pickImage`, `PickedFile`→`XFile?`, two `currentDevice.id`→`.remoteId`, `archive_io` import (esk8Configuration.dart).
- Two `catchError`/`catch` handlers accessing `.message`/`.code` on `Object` (main.dart:638, 736).
- `share_plus` ^10→^13 (win32 conflict; code already used the v11+ API).

### Remaining: **4,309 analyzer errors** — all null-safety usage-site fan-out
Breakdown by type: `unchecked_use_of_nullable_value` 2,341 · `argument_type_not_assignable` 1,599 · `invalid_assignment` 105 · `not_assigned_potentially_non_nullable_local_variable` 94 · `not_initialized_non_nullable_instance_field` 85 · `missing_default_value_for_parameter` 47 · misc 38.

Top files: inputConfigurationEditor 554 · rideLogViewer 552 · firmware serializers (6 files) 1,796 · main.dart 292 · motorConfigurationEditor 187 · rideLogging 139 · realTimeData 97.

**Root cause / strategy correction (important):** the declaration migration added `?` to *every* uninitialized field, including ~600 fields in `MCCONF`/`APPCONF` and the telemetry structs. Those structs are always fully populated by the firmware deserializers before use — making them nullable poisoned every read site downstream (the 6 serializer files alone are 1,796 errors and were never edited; the errors are pure fan-out). **Do not fix those call sites one by one.**

## 7. ACTION PLAN (ordered, with expected error burn-down)

**Phase A — De-nullable the data models (eliminates ~2,400+ errors)**
In `mcConf.dart`, `appConf.dart` (and the few remaining nullable fields in `escHelper.dart` telemetry classes): replace `double? x;` → `double x = 0;`, `int? x;` → `int x = 0;`, `bool? x;` → `bool x = false;`, enums → first enum value (matches what the deserializer writes anyway; the app never reads these before deserialization or `ESCHelper` defaults fill them). This zeroes the serializer errors *without touching the serializer files* and kills most of input/motorConfigurationEditor. Same treatment for `logFileParser.dart` (LogESC/LogGPS) and `userSettings.dart` (`UserSettingsStructure` — it has a `defaults()`-style initializer; fields can be non-nullable with defaults).

**Phase B — View-layer null handling (main.dart, rideLogViewer, rideLogging, realTimeData, brocator, connectionStatus, fileSyncViewer, speedProfiles, esk8Configuration, vehicleManager)**
Mechanical per-site fixes now that models are sane: `!` where a connection/argument is guaranteed (e.g. `theTXCharacteristic!.write` after connect), `?.`/`??` for genuinely-optional UI state, `late` for `initState`-assigned fields (e.g. `TabController`), local-variable definite-assignment fixes. Budget: this is the long tail; do it file-by-file, `flutter analyze` after each file. `missing_default_value_for_parameter` (47) = optional params needing `?` or a default.

**Phase C — Replace logger_flutter properly** (see §5.1) and verify `flutter_nordic_dfu` (§5.2).

**Phase D — Build & runtime verification**
`flutter build apk --release` must succeed; then on-device/BLE smoke test: scan→connect→RT telemetry→ride log sync→config editor read/write. Also fix the 2 Dependabot alerts on master (visible in repo Security tab).

**Phase E — Finish the bloc migration (optional, perf goal)**
Wire the 4 dead blocs (BLEConnection, FileSync, Robogotchi, ESCConfig) or delete them; replace `context.watch` at top of `RealTimeData.build()` with scoped `BlocBuilder(buildWhen:)` so the 50 ms tick redraws only gauge widgets (audit item H3); fix `FileSyncBloc._onEraseToggled` not emitting (M4); rideLogging sort-clause load race (M3).

## 8. CI (implemented this session)

`.github/workflows/android-release.yml`:
- **Triggers:** `push` to `master` only (i.e. on merge) + `workflow_dispatch` for manual runs (this is the agreed policy: PRs do not build automatically — trigger manually from the Actions tab).
- Flutter 3.44.5 pinned, Java 17, `flutter analyze` is **non-blocking** until Phase B completes (flip `|| true` off then).
- Signing: set repo variable `HAS_SIGNING=true` + secrets `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` (full walkthrough in `CI_GUIDE.md`). Without them the workflow still produces a debug-signed release APK artifact.
- Note: the build will fail until Phase A/B fix the compile errors — the workflow is in place so it goes green the moment the code does.

## 9. Bloc architecture reference

```
lib/blocs/
  preferences/  PreferencesCubit + PreferencesState     WIRED (realTimeData, rideLogging)
  telemetry/    TelemetryBloc: private internal events;
                public updateTelemetry()/updateDieBieMS()/
                clearDieBieMS()/resetForDisconnect()     WIRED (main.dart 50ms path)
  location/     LocationBloc (GPS stream + route)        provided, NOT auto-started (main.dart owns GPS)
  ble_connection/ BLEConnectionBloc                      provided, not wired
  file_sync/    FileSyncBloc                             provided, not wired
  robogotchi/   RobogotchiBloc                           provided, not wired
  esc_config/   ESCConfigBloc                            provided, not wired
```
Conventions: Equatable events/states with `List<Object?> props`; never call `emit()` outside a registered handler — use private internal event classes + public `add()`-wrapping methods (see TelemetryBloc); `copyWith` uses nullable params + `??` (plus explicit `clearX` flags where null is a meaningful value, e.g. `clearDieBieMS`).

Key UUIDs (UART service): `6e400001-…` service, `…0002` TX, `…0003` RX, `…0004` TX-logger, `…0005` RX-logger (logger chars present ⇒ Robogotchi, else direct ESC).

## 10. Gotchas discovered the hard way

- `ESCTelemetry`/`ESCFault` live in `hardwareSupport/escHelper/escHelper.dart`, **not** `dataTypes.dart`; `InputCalibration` lives in `subViews/inputConfigurationEditor.dart`; `TimeSeriesESC` lives at the bottom of `rideLogViewer.dart`.
- `Stream.exhaustMap` does not exist in Dart — don't invent bloc EventTransformers with it.
- flutter_blue_plus 2.3.10 `connect()` requires `license:`; FreeSK8 qualifies for `License.nonprofit`.
- `community_charts_flutter`'s import is `community_charts_flutter.dart` (the old `charts_flutter/flutter.dart` path pattern does not carry over).
- Marker `builder:` param indentation varies across rideLogViewer — a plain string replace missed one at 6-space indent; grep after bulk edits.
- Font-size preference historical minimum is **14**, not 10 (regression was caught by audit and fixed).
- The RT view previously only kept first+current GPS points (route tracking via phone GPS is intentionally disabled in `updateLocationForRoute` — don't "fix" it back on).

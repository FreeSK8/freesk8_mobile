# Android Release CI Guide

How the GitHub Actions workflow in `.github/workflows/android-release.yml` builds, signs and
publishes FreeSK8 Mobile for Android, and the one-time setup it needs.

> **Status:** the workflow is in place. Release signing only becomes active once the keystore
> secrets and the `HAS_SIGNING` repository variable exist (Steps 1-3). Until then every build
> is debug-signed: the APK is named `-debug-signed` and any GitHub Release made from it is
> marked as a pre-release.

---

## How the workflow runs

| Event | What happens |
|---|---|
| push to `master` | build, `flutter analyze`, `flutter test`, `flutter build apk --release`; the APK is uploaded as a 30-day workflow artifact named `freesk8_mobile-<version>-g<sha>-<signed\|debug-signed>` |
| push of a tag `vX.Y.Z` | same build, then a **GitHub Release** for the tag with the APK and its `.sha256` attached, the matching `CHANGELOG` section as the body, and auto-generated notes |
| push of a tag `vX.Y.Z-<suffix>` (e.g. `v0.24.0-rc1`) | same as above, marked **pre-release** |
| manual run (Actions tab) | builds any branch or tag; choose `apk` or `appbundle`. A Release is published only when the run is dispatched on a `v*` tag ref with `publish_release` ticked (use this to retry a failed upload) |

Guards that fail the run early:

- `pubspec.yaml` must have a `version:` line and `lib/main.dart`'s `freeSK8ApplicationVersion`
  must equal its version name (`test/version_test.dart` checks the same thing locally).
- On a tag ref, the tag must be `v<version name>` or `v<version name>-<suffix>`.
- If `HAS_SIGNING` is `true` but the built APK is still debug-signed, the job fails.

The Flutter version is not in the workflow: it comes from `environment.flutter` in `pubspec.yaml`
(`subosito/flutter-action` reads it via `flutter-version-file`). Bump it there.

Toolchain the workflow expects: Java 17 (Temurin), Gradle 8.11.1 / AGP 8.9.1 / Kotlin 2.2.0
(`android/settings.gradle`, `android/gradle/wrapper/gradle-wrapper.properties`),
compileSdk / targetSdk 36 (`android/app/build.gradle`).

---

## Step 1 - Generate a release keystore (one time)

Run this on your local machine, outside the repository, and keep the output file safe (Step 2).
`keytool` is part of a JDK and is usually not on PATH; on macOS the bare `java` stub only prints
"Unable to locate a Java Runtime".

With Android Studio installed, use its bundled JDK (`flutter doctor -v` prints the path after
"Java binary at:", and `keytool` sits next to `java`):

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v \
  -keystore release.keystore -alias freesk8 -keyalg RSA -keysize 2048 -validity 10000
```

Without Android Studio, install a JDK first (`brew install --cask temurin@21` on macOS,
`sudo apt install openjdk-21-jdk-headless` on Debian/Ubuntu), open a new shell, and run plain
`keytool`:

```bash
keytool -genkey -v -keystore release.keystore -alias freesk8 -keyalg RSA -keysize 2048 -validity 10000
```

Command blocks in this guide carry no comments: zsh, the macOS default shell, does not accept `#`
comments on an interactive command line.

At the prompt "Enter key password for <freesk8>" press RETURN so the key password equals the
store password: one password to keep, and the backup entry in Step 2 needs only one password
field. You will need the `release.keystore` file, the `keyAlias` (`freesk8`), the `storePassword`
and the `keyPassword`. Losing the keystore means future builds can no longer upgrade installed
copies in place, so back it up (Step 2).

## Step 2 - Encode the keystore as base64 and back it up

macOS:

```bash
base64 -i release.keystore | tr -d '\n' > release.keystore.b64
```

Linux:

```bash
base64 -w 0 release.keystore > release.keystore.b64
```

Keep the keystore and its password in one password-manager entry, with the base64 text standing
in for the file (it is exactly what the `KEYSTORE_BASE64` secret holds). The notes must hold the
base64 text and nothing else: a password line above it decodes as base64 too and corrupts a
restore.

- Apple Passwords: File -> New Password; user name `freesk8` (the alias), password = store
  password, notes = the contents of `release.keystore.b64` only
  (`pbcopy < release.keystore.b64`, then paste). A key password that differs from the store
  password goes into a second entry, never into the notes. Older macOS: Keychain Access -> File
  -> New Secure Note Item, same rule.
- 1Password / Bitwarden Premium: attach `release.keystore` to the item instead.

Prove the backup restores before deleting anything local. Do not go through the clipboard
(copying a command replaces what you copied from the password manager): run `cat > restore.b64`,
paste the base64 from the entry, press Return, then Ctrl-D, and:

```bash
KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
tr -d '\n' < restore.b64 | base64 -d > restored.keystore
shasum -a 256 release.keystore restored.keystore
"$KEYTOOL" -list -v -keystore restored.keystore
rm restore.b64 restored.keystore
```

After a Temurin or apt install use `KEYTOOL=keytool`. The two hashes must be identical and the
listing must show one entry, `freesk8`. If the hashes differ, `wc -c restore.b64` should match
`wc -c release.keystore.b64` within a byte; a much smaller file means the paste was incomplete or
held other text.

Delete `release.keystore.b64` once the secret in Step 3 is set.

## Step 3 - Add the GitHub secrets and variable

**GitHub -> repo -> Settings -> Secrets and variables -> Actions**

Secrets:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | contents of `release.keystore.b64` |
| `KEY_ALIAS` | e.g. `freesk8` |
| `KEY_PASSWORD` | key password |
| `STORE_PASSWORD` | store password |

Variable (the *Variables* tab, not a secret):

| Variable | Value |
|---|---|
| `HAS_SIGNING` | `true` |

Or with the GitHub CLI, from a clone of the repository:

```bash
brew install gh && gh auth login
gh secret set KEYSTORE_BASE64 < release.keystore.b64
gh secret set KEY_ALIAS --body freesk8
gh secret set KEY_PASSWORD
gh secret set STORE_PASSWORD
gh variable set HAS_SIGNING --body true
gh secret list && gh variable list
```

The first line is a one-time install and login; the two password lines prompt for the value, so
nothing lands in shell history.

Passwords may contain any characters: the workflow passes them through the environment and
writes `android/key.properties` with `printf`, so nothing is shell-expanded.

Set these **before** tagging the first real release; a release built without them is
debug-signed and published as a pre-release.

## Step 4 - Local release builds (optional)

`android/app/build.gradle` reads `android/key.properties` when it exists and falls back to the
debug key otherwise. For a signed local build create (never commit) `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=freesk8
storeFile=release.keystore
```

and put `release.keystore` in `android/app/`. Both paths are ignored by the root `.gitignore`
(`android/key.properties`, `android/app/release.keystore`).

---

## Tagging and releasing

1. In the pull request that finishes a version: bump `version:` in `pubspec.yaml` (name and
   build number, e.g. `0.24.0+52`), set `freeSK8ApplicationVersion` in `lib/main.dart` to the
   same name, and add a `vX.Y.Z` section to `CHANGELOG` (the release body is copied from it).
2. Merge to `master`. The master push builds and uploads an artifact only.
3. Tag the merge commit and push the tag:

   ```bash
   git checkout master && git pull
   git tag -a v0.24.0 -m "FreeSK8 Mobile v0.24.0"
   git push origin v0.24.0
   ```

4. Watch the **Android Release** run. The `release` job publishes
   `https://github.com/FreeSK8/freesk8_mobile/releases/tag/v0.24.0` with
   `freesk8_mobile-v0.24.0-signed.apk` and `.sha256`.

To rehearse without a real release, push `v0.24.0-rc1`; it publishes a pre-release. Remove it
and its tag afterwards in one go:

```bash
gh release delete v0.24.0-rc1 --yes --cleanup-tag
```

Without the GitHub CLI, delete the pre-release in the GitHub UI, then remove the tag:

```bash
git push origin :refs/tags/v0.24.0-rc1
```

---

## Optional: publish to Google Play

Add a step after the App Bundle build (run the workflow manually with `build_type: appbundle`).
It needs a Google Play service account JSON stored as the secret `PLAY_STORE_SERVICE_ACCOUNT_JSON`:

```yaml
      - name: Upload to Play Store (internal track)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT_JSON }}
          packageName: com.derelictrobot.freesk8_mobile
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal
```

## Notes

- **Artifacts** are under *Actions -> (run) -> Artifacts*. The APK can be sideloaded; the AAB is for Play.
- **Caching:** `flutter-action` caches the Flutter SDK and `setup-java` caches Gradle between runs.
- **Dependencies** all come from pub.dev; there are no git dependencies, so runners need no SSH key.

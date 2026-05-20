# Android Release CI Guide

Step-by-step instructions for setting up GitHub Actions to build and sign a release APK/AAB for FreeSK8 Mobile.

---

## Prerequisites

- Java `keytool` available locally (ships with the JDK)
- Access to the GitHub repo's Settings > Secrets

---

## Step 1 — Generate a release keystore (one time)

Run this on your local machine and store the output file somewhere safe (password manager, not the repo):

```bash
keytool -genkey -v \
  -keystore release.keystore \
  -alias freesk8 \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

You will need:
- The `release.keystore` file
- Your chosen `keyAlias` (e.g. `freesk8`)
- `storePassword` (set during keytool prompt)
- `keyPassword` (set during keytool prompt)

---

## Step 2 — Encode the keystore as base64

```bash
# Linux / macOS
base64 -w 0 release.keystore > release.keystore.b64

# macOS alternative
base64 release.keystore | tr -d '\n' > release.keystore.b64
```

Copy the entire contents of `release.keystore.b64` — you'll paste it as a GitHub secret.

---

## Step 3 — Add GitHub Secrets

**GitHub → repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | The base64 string from step 2 |
| `KEY_ALIAS` | e.g. `freesk8` |
| `KEY_PASSWORD` | Key password |
| `STORE_PASSWORD` | Store password |

If Firebase is re-enabled in the future, also add:

| Secret name | Value |
|---|---|
| `GOOGLE_SERVICES_JSON` | Full contents of `android/app/google-services.json` |

---

## Step 4 — Update `android/app/build.gradle` for release signing

The current build.gradle uses `signingConfigs.debug` for release builds (a placeholder). Replace it with a proper release signing config that reads from `key.properties`.

**Add near the top of the file** (after the `flutterVersionName` block):

```groovy
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withReader('UTF-8') { reader ->
        keystoreProperties.load(reader)
    }
}
```

**Update the `android { }` block** to add a `signingConfigs` section and use it in `buildTypes.release`:

```groovy
android {
    compileSdkVersion 35
    // ... existing config unchanged ...

    signingConfigs {
        release {
            keyAlias     keystoreProperties['keyAlias']
            keyPassword  keystoreProperties['keyPassword']
            storeFile    keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // shrinkResources and minifyEnabled can be enabled here if desired
        }
    }
}
```

---

## Step 5 — Gitignore the key files

Add to `android/.gitignore` (create if it doesn't exist):

```
key.properties
*.keystore
*.jks
release.keystore.b64
```

For local builds, create `android/key.properties` manually (never commit this):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=freesk8
storeFile=../release.keystore
```

---

## Step 6 — Create the workflow file

Create `.github/workflows/android-release.yml`:

```yaml
name: Android Release Build

on:
  push:
    branches:
      - 'flutter-3.41-dart-3.11'
      - 'main'
      - '[0-9]+.[0-9]+.[0-9]+'   # version branches e.g. 0.23.0
  workflow_dispatch:              # allows manual trigger from Actions tab

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter 3.41.5
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/release.keystore

      - name: Write key.properties
        run: |
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.STORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          storeFile=../release.keystore
          EOF

      # Uncomment if Firebase is re-enabled:
      # - name: Write google-services.json
      #   run: echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json

      - name: Build release APK
        run: flutter build apk --release

      - name: Build release AAB (Play Store)
        run: flutter build appbundle --release

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: freesk8-release-${{ github.sha }}
          path: |
            build/app/outputs/flutter-apk/app-release.apk
            build/app/outputs/bundle/release/app-release.aab
          retention-days: 30
```

---

## Step 7 — Optional: auto-publish to Play Store

Append this step after the build steps if you want CI to push directly to a Play Store track.  
Requires a Google Play service account JSON (see [Google Play docs](https://developers.google.com/android-publisher/getting_started)).

Add secret `PLAY_STORE_SERVICE_ACCOUNT_JSON` = the service account JSON contents, then add:

```yaml
      - name: Upload to Play Store (internal track)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT_JSON }}
          packageName: com.derelictrobot.freesk8_mobile
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal
```

---

## Notes

### Git dependencies use HTTPS (already done in this branch)

The `pubspec.yaml` git deps (`flutter_nordic_dfu`, `logger_flutter`) have been switched from SSH to HTTPS URLs so they resolve correctly on GitHub Actions runners without needing an SSH key.

### Artifacts

Downloaded from **GitHub → repo → Actions → (workflow run) → Artifacts**.  
The APK can be sideloaded directly; the AAB is for the Play Store.

### Caching

The `subosito/flutter-action@v2` `cache: true` option caches the Flutter SDK and pub cache between runs, significantly reducing build time after the first run.

# ESC configuration serializers

The Dart classes in `lib/hardwareSupport/escHelper/serialization/firmware*.dart`
are **generated**. They read and write the VESC motor configuration (MCCONF) and
app configuration (APPCONF) byte-for-byte the way each firmware release does,
because they are derived from the firmware's own `confgenerator.c`.

Never edit the generated files by hand; CI runs `generate.py --check` and fails
when they are stale.

## Layout

| Path | Purpose |
| --- | --- |
| `generate.py` | Generator (Python 3, standard library only) |
| `versions.json` | Which firmware versions are generated, class/file names, field renames |
| `vesc/<label>/` | Vendored firmware sources: `confgenerator.c`, `confgenerator.h`, `datatypes.h`, plus a `SOURCE` file with the git ref, commit and fetch date |
| `layouts/<label>.json` | Signature, byte size and ordered field list per version (checked by `test/esc_serializers_test.dart`) |

## Vendored firmware sources

All files come from <https://github.com/vedderb/bldc> (GPL-3.0, the same licence
as this app). The exact ref and commit of every copy is recorded in its
`SOURCE` file.

| Label | Firmware | Git ref | Serves |
| --- | --- | --- | --- |
| 5.1 | 5.01 | tag `5.01` | FW5_1 |
| 5.2 | 5.02 | tag `5.02` | FW5_2 |
| 5.3 | 5.03 | tag `5.03` | FW5_3 |
| 6.0 | 6.00 / 6.02 | tag `6.00` | FW6_0, FW6_2 (identical layout and signatures) |
| 6.05 | 6.05 | branch `release_6_05` | FW6_5 |
| 6.06 | 6.06 | branch `release_6_06` | FW6_6 |
| 7.0 | 7.00 | branch `release_7_00` | FW7_0 |

## Regenerating

```sh
python3 tool/esc_serializers/generate.py          # rewrite the Dart files and layouts
python3 tool/esc_serializers/generate.py --check  # what CI runs
flutter test test/esc_serializers_test.dart
```

## Adding a firmware release

1. Fetch `confgenerator.c`, `confgenerator.h` and `datatypes.h` for the release
   from the bldc repository into `vesc/<label>/` and write a `SOURCE` file next
   to them (repo, ref, commit, fetch date, file list). From the repository root,
   with `REF` the bldc branch or tag and `V` the label:

   ```sh
   REF=release_7_01; V=7.01; DIR=tool/esc_serializers/vesc/$V; mkdir -p $DIR
   for f in confgenerator.c confgenerator.h datatypes.h; do
     curl -fsSL https://raw.githubusercontent.com/vedderb/bldc/$REF/$f -o $DIR/$f; done
   SHA=$(git ls-remote https://github.com/vedderb/bldc "refs/heads/$REF" "refs/tags/$REF" | tail -1 | cut -f1)
   printf 'repo=https://github.com/vedderb/bldc\nref=%s\ncommit=%s\nfetched=%s\nfiles=confgenerator.c confgenerator.h datatypes.h\n' \
     "$REF" "$SHA" "$(date +%F)" > $DIR/SOURCE
   ```
2. Add the version to `versions.json`: `label`, `ref`, the Dart `class` and
   `file` names, and the `ESC_FIRMWARE` members it serves.
3. Add the new `ESC_FIRMWARE` member in `lib/hardwareSupport/escHelper/escHelper.dart`,
   register the serializer in `ESCHelper.serializers`, and teach
   `ESCHelper.firmwareFor()` the major/minor pair. Adjust `FirmwareFeatures`
   if the release adds or removes fields the settings screens show.
4. Run the generator. It stops with a list of C fields or enum members the Dart
   data classes (`mcConf.dart`, `appConf.dart`, `dataTypes.dart`) do not have yet;
   add them (the classes are the union of every supported version) or map a
   renamed field in `versions.json`. Repeat until the generator is clean.
5. Add the version to `test/esc_serializers_test.dart` (the per-version table)
   and `test/esc_firmware_detection_test.dart`, run the tests, and list the
   release in the README's supported firmware table.

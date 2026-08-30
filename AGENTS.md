# AGENTS.md

MDD Player is a Flutter **Android** app (a fork of SongTube): a music/video
player with downloads, offline mode and data-saving. See `README.md` for the
product overview and `plan.md` for the detailed engineering log.

## Cursor Cloud specific instructions

### Toolchain (already installed in the environment)

- **Flutter** `stable` (3.47.x) is installed at `$HOME/flutter`. Dart ships with it.
- **JDK 17** is installed at `/usr/lib/jvm/java-17-openjdk-amd64`. This exact path
  is **hard-coded** in `android/gradle.properties` (`org.gradle.java.home`), so the
  Android build requires JDK 17 there even though the system default is JDK 21.
- **Android SDK** is at `$HOME/android-sdk` (platform 34, build-tools 34.0.0,
  platform-tools, NDK). `flutter config` already points `android-sdk` and
  `jdk-dir` at these locations.
- `~/.bashrc` exports `JAVA_HOME`, `ANDROID_HOME`/`ANDROID_SDK_ROOT` and prepends
  `flutter`/Android tools to `PATH`. Interactive shells get this automatically; in
  a non-interactive shell either `source ~/.bashrc` or call tools by full path
  (e.g. `$HOME/flutter/bin/flutter`).

### Dependencies + required pub-cache patches

Several dependencies are unmaintained and shipped for AGP 7 / Flutter v1
embedding; their fixes were never upstreamed, so a clean `flutter pub get`
re-fetches sources that do **not** build. `tool/patch_pub_cache.sh` (with
`tool/patch_pub_cache.py`) re-applies the required, deterministic fixes to the
resolved packages. It is **idempotent** and must be run after every
`flutter pub get`:

```bash
flutter pub get && bash tool/patch_pub_cache.sh
```

This is also the environment update script, so a fresh Cloud Agent VM already has
the patches applied. Do **not** run `flutter pub cache clean`/`repair` without
re-running the patch script afterwards. What it fixes: `newpipeextractor_dart`
(`force = true`, JitPack coordinate case), legacy `package=` manifest attributes
(AGP 8), Flutter v1 embedding remnants (`registerWith`, `Registrar`
fields/params/branches, `FlutterView`), `win32` `UnmodifiableUint8ListView`,
`IconData`-subclassing icon packages (eva/ionicons/material_design_icons), and
`sensors_plus` nullability.

### Everyday commands

- Refresh + patch dependencies: `flutter pub get && bash tool/patch_pub_cache.sh`.
- Lint / static analysis: `flutter analyze` (config in `analysis_options.yaml`).
  A clean checkout reports **0 errors** plus ~400 pre-existing info/warning lints;
  `flutter analyze` exits non-zero whenever any lint exists, so check for `error •`
  lines rather than the exit code. Note: `flutter analyze` only analyses the app's
  own `lib/`, not dependency internals, so it will **not** catch the dependency
  build errors above — those only appear at `flutter build`/compile time.
- Build the debug APK (fast, single-ABI for iteration):
  `flutter build apk --debug --target-platform android-arm64 --android-skip-build-dependency-validation`
- There is **no `test/` directory**, so `flutter test` has nothing to run.

### Build notes

- The Gradle wrapper is pinned at 8.10.2 while recent Flutter stable expects
  8.14+, so builds pass `--android-skip-build-dependency-validation` (Gradle
  8.10.2 itself works). The full multi-ABI universal APK omits x86/x86_64 for
  release (see `android/app/build.gradle`); build a single ABI to iterate faster.

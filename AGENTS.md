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
  platform-tools). `flutter config` already points `android-sdk` and `jdk-dir`
  at these locations.
- `~/.bashrc` exports `JAVA_HOME`, `ANDROID_HOME`/`ANDROID_SDK_ROOT` and prepends
  `flutter`/Android tools to `PATH`. Interactive shells get this automatically; in
  a non-interactive shell either `source ~/.bashrc` or call tools by full path
  (e.g. `$HOME/flutter/bin/flutter`).

### Everyday commands

- Refresh dependencies: `flutter pub get` (this is also the environment update script).
- Lint / static analysis: `flutter analyze` (config in `analysis_options.yaml`).
  A clean checkout reports **0 errors** plus ~400 pre-existing info/warning lints;
  `flutter analyze` exits non-zero whenever any lint exists, so check for `error •`
  lines rather than the exit code.
- There is **no `test/` directory**, so `flutter test` has nothing to run.

### Known blocker: `flutter build apk` does NOT work from a clean checkout

Building the APK currently **fails on a fresh machine**. The maintainer's working
build depends on ~30 manual patches that live only in their local `~/.pub-cache`
and were **never committed, vendored, forked, or upstreamed** (documented in the
`plan.md` bitácora). On a clean `flutter pub get` these come back unpatched, so the
build breaks. Confirmed still-unpatched blockers include:

- `newpipeextractor_dart` (git dep) `android/build.gradle`: `force = true` (removed
  in Gradle 8 — triggers an infinite-loop hang in Gradle's error handler) and a
  case-wrong JitPack coordinate (`teamnewpipe` should be `TeamNewPipe`).
- **34 plugin `AndroidManifest.xml`** files still declare `package="..."`, which
  AGP 8 rejects.
- **~12 plugins** still contain Flutter v1 embedding code (`PluginRegistry.Registrar`).

Because these patches are non-idempotent (any `flutter pub get` / `flutter pub cache
clean`/`repair` or git-dep ref change wipes them) they are intentionally **not** in
the environment update script. Producing a buildable APK requires upstreaming or
vendoring those fixes in the repository first — that is a code change, not an
environment change. **Do not run `flutter pub cache clean`/`repair`.**

Note: the Gradle wrapper is pinned at 8.10.2 while recent Flutter stable requires
8.14+, so even after the pub-cache fixes a build needs
`--android-skip-build-dependency-validation` (or a Flutter version matching the
wrapper). Building also requires installing an NDK.

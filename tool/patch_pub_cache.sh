#!/usr/bin/env bash
#
# Patches abandoned/old dependencies in the pub-cache so the app builds with a
# modern Android toolchain (AGP 8 / Gradle 8 / current Flutter embedding).
#
# WHY THIS EXISTS
# Several dependencies are unmaintained and were last published for AGP 7 /
# Flutter v1 embedding. Their fixes were never upstreamed, so a clean
# `flutter pub get` re-fetches broken sources. This script re-applies the
# required, deterministic fixes to the resolved packages (versions are pinned
# in pubspec.lock, so the targets are stable).
#
# The script is IDEMPOTENT: it is safe to run after every `flutter pub get`
# (including after `flutter pub cache clean/repair`). Run it via:
#   flutter pub get && bash tool/patch_pub_cache.sh
#
set -euo pipefail

# Resolve the pub-cache location (respect PUB_CACHE, fall back to the default).
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
if [ ! -d "$PUB_CACHE_DIR" ]; then
  echo "patch_pub_cache: pub-cache not found at $PUB_CACHE_DIR" >&2
  exit 1
fi
echo "patch_pub_cache: using pub-cache at $PUB_CACHE_DIR"

changed=0

# ---------------------------------------------------------------------------
# 1) newpipeextractor_dart (git dep): the Android build.gradle uses the
#    Gradle-7-only `force = true` (removed in Gradle 8, causes an infinite
#    loop in Gradle's error handler) and a case-wrong JitPack coordinate
#    (`teamnewpipe` -> `TeamNewPipe`, JitPack is case-sensitive).
# ---------------------------------------------------------------------------
while IFS= read -r -d '' gradle; do
  if grep -q 'teamnewpipe' "$gradle"; then
    sed -i 's#com.github.teamnewpipe:NewPipeExtractor#com.github.TeamNewPipe:NewPipeExtractor#g' "$gradle"
    echo "patch_pub_cache: fixed JitPack coordinate case in $gradle"
    changed=1
  fi
  if grep -q 'force = true' "$gradle"; then
    # Turn the spotbugs dependency's `force = true` block into the Gradle-8
    # strict-version syntax on the coordinate and drop the removed API.
    sed -i "s#implementation ('com.github.spotbugs:spotbugs-annotations:\([0-9.]*\)'){#implementation ('com.github.spotbugs:spotbugs-annotations:\1!!') {#g" "$gradle"
    sed -i '/force = true/d' "$gradle"
    echo "patch_pub_cache: removed Gradle-8-incompatible force=true in $gradle"
    changed=1
  fi
done < <(find "$PUB_CACHE_DIR" -path '*NewPipeExtractor_Dart*/android/build.gradle' -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# 2) AGP 8 rejects the legacy `package="..."` attribute in library manifests
#    (the namespace is injected by android/build.gradle instead). Strip it
#    from every plugin manifest in the cache that still declares it.
# ---------------------------------------------------------------------------
while IFS= read -r -d '' manifest; do
  if grep -q 'package="' "$manifest"; then
    sed -i -E 's/ package="[^"]*"//' "$manifest"
    changed=1
  fi
done < <(find "$PUB_CACHE_DIR" \( -path '*/android/src/main/AndroidManifest.xml' -o -path '*/android/src/*/AndroidManifest.xml' \) -print0 2>/dev/null)
echo "patch_pub_cache: stripped legacy package= attributes from plugin manifests"

# ---------------------------------------------------------------------------
# 3) Flutter removed the v1 embedding (io.flutter.plugin.common.PluginRegistry
#    .Registrar). Old plugins still ship a `registerWith(Registrar)` static
#    method (and/or the import), which no longer compiles. Strip the v1 import
#    and the v1 registration method; the v2 embedding path is kept intact.
#    Only main sources are touched (test sources aren't compiled by the app).
# ---------------------------------------------------------------------------
strip_v1_embedding() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk '
    function scan(line,   i, ch) {
      for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1);
        if (ch == "{") { depth++; seen = 1; }
        else if (ch == "}") { depth--; }
      }
    }
    # Drop the v1 import (both fully qualified and short forms).
    /^[[:space:]]*import[[:space:]]+io\.flutter\.plugin\.common\.PluginRegistry\.Registrar;[[:space:]]*$/ { next }
    skip == 1 { scan($0); if (seen && depth <= 0) { skip = 0 } next }
    /static[[:space:]]+void[[:space:]]+registerWith[[:space:]]*\(/ {
      skip = 1; depth = 0; seen = 0; scan($0);
      if (seen && depth <= 0) { skip = 0 }
      next
    }
    { print }
  ' "$file" > "$tmp"
  if ! cmp -s "$file" "$tmp"; then
    mv "$tmp" "$file"
    echo "patch_pub_cache: removed v1 embedding from ${file#$PUB_CACHE_DIR/}"
    changed=1
  else
    rm -f "$tmp"
  fi
}

while IFS= read -r -d '' javafile; do
  if grep -q 'PluginRegistry.Registrar' "$javafile"; then
    strip_v1_embedding "$javafile"
  fi
done < <(find "$PUB_CACHE_DIR" -path '*/android/src/main/*' -name '*.java' -print0 2>/dev/null)

# 3b) Remaining v1-embedding remnants (constructors, fields, and
#     `if (registrar != null)` branches) that need per-package edits.
if command -v python3 >/dev/null 2>&1; then
  PUB_CACHE="$PUB_CACHE_DIR" python3 "$(dirname "$0")/patch_pub_cache.py"
else
  echo "patch_pub_cache: python3 not found, skipping v1 remnant patches" >&2
fi

# ---------------------------------------------------------------------------
# 4) Dart-level breakage on modern Dart SDKs (these are internal to the
#    dependencies, so `flutter analyze` on the app does not surface them).
# ---------------------------------------------------------------------------

# 4a) win32 4.x uses UnmodifiableUint8ListView, removed from dart:typed_data.
while IFS= read -r -d '' guid; do
  if grep -q 'UnmodifiableUint8ListView' "$guid"; then
    sed -i 's/UnmodifiableUint8ListView bytes;/Uint8List bytes;/g' "$guid"
    sed -i -E 's/UnmodifiableUint8ListView\(/Uint8List.fromList(/g' "$guid"
    echo "patch_pub_cache: fixed removed UnmodifiableUint8ListView in ${guid#$PUB_CACHE_DIR/}"
    changed=1
  fi
done < <(find "$PUB_CACHE_DIR" -path '*win32*/lib/src/guid.dart' -print0 2>/dev/null)

# 4b) Icon packages subclass IconData, which is now a `final` class and cannot
#     be extended. Rewrite the `XxxIconData(0x..)` constants to build IconData
#     directly and drop the now-unused subclass.
#     Args: <glob-relative-file> <ClassName> <fontFamily> <fontPackage>
patch_icon_font() {
  local file="$1" cls="$2" family="$3" pkg="$4"
  [ -f "$file" ] || return 0
  local touched=0
  # Rewrite call-sites XxxIconData(<codePoint>) -> IconData(<codePoint>, ...).
  # <codePoint> is a hex literal (0x..) in the generated constants or a bare
  # identifier in helper methods; the single-token match deliberately excludes
  # the `XxxIconData(int codePoint)` constructor declaration (it has a space).
  if grep -qE "${cls}\(" "$file"; then
    sed -i -E "s/${cls}\(([0-9a-zA-Z_]+)\)/IconData(\1, fontFamily: '${family}', fontPackage: '${pkg}')/g" "$file"
    touched=1
  fi
  # Remove the subclass definition (brace-balanced), if present in this file.
  grep -q "class $cls extends IconData" "$file" || { [ "$touched" -eq 1 ] && { echo "patch_pub_cache: rewrote $cls constants in ${file#$PUB_CACHE_DIR/}"; changed=1; }; return 0; }
  local tmp; tmp="$(mktemp)"
  awk -v cls="$cls" '
    function scan(line,   i, ch) {
      for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1);
        if (ch == "{") { depth++; seen = 1; }
        else if (ch == "}") { depth--; }
      }
    }
    skip == 1 { scan($0); if (seen && depth <= 0) { skip = 0 } next }
    $0 ~ ("class " cls " extends IconData") {
      skip = 1; depth = 0; seen = 0; scan($0);
      if (seen && depth <= 0) { skip = 0 }
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "patch_pub_cache: rewrote $cls IconData subclass in ${file#$PUB_CACHE_DIR/}"
  changed=1
}

for d in "$PUB_CACHE_DIR"/hosted/pub.dev/eva_icons_flutter-*; do
  patch_icon_font "$d/lib/src/eva_icons_flutter.dart" "EvaIconData" "EvaIcons" "eva_icons_flutter"
  patch_icon_font "$d/lib/src/icon_data.dart" "EvaIconData" "EvaIcons" "eva_icons_flutter"
done
for d in "$PUB_CACHE_DIR"/hosted/pub.dev/ionicons-*; do
  patch_icon_font "$d/lib/ionicons.dart" "IoniconsData" "Ionicons" "Ionicons"
done
for d in "$PUB_CACHE_DIR"/hosted/pub.dev/material_design_icons_flutter-*; do
  patch_icon_font "$d/lib/material_design_icons_flutter.dart" "_MdiIconData" "Material Design Icons" "material_design_icons_flutter"
done

if [ "$changed" -eq 1 ]; then
  echo "patch_pub_cache: done (patches applied)"
else
  echo "patch_pub_cache: done (nothing to change)"
fi

#!/usr/bin/env python3
"""Bespoke, idempotent patches for Flutter v1-embedding remnants in old plugins.

Some unmaintained plugins keep v1-embedding code (constructors, fields, or
`if (registrar != null)` branches) that no longer compiles because
`io.flutter.plugin.common.PluginRegistry.Registrar` was removed. The generic
`registerWith` removal in patch_pub_cache.sh handles the static registration
method; this script removes the remaining v1-only code while preserving the v2
path. Package versions are pinned in pubspec.lock, so these targets are stable.

Idempotent: only rewrites a file when the "before" text is still present.
"""
import glob
import os
import sys

PUB_CACHE = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))


def apply(path_glob, replacements):
    for path in glob.glob(os.path.join(PUB_CACHE, path_glob)):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        original = text
        for before, after in replacements:
            if before in text:
                text = text.replace(before, after)
        if text != original:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("patch_pub_cache.py: patched " + os.path.relpath(path, PUB_CACHE))


# Shared v1/v2 methods: the `registrar` parameter type no longer exists. It is
# only ever passed `null` by the v2 embedding, so widen it to Object.
PARAM_TYPE = [
    ("final PluginRegistry.Registrar registrar,", "final Object registrar,"),
    (
        "final io.flutter.plugin.common.PluginRegistry.Registrar registrar,",
        "final Object registrar,",
    ),
]

# 1) video_player (SongTube fork): dead v1-only private constructor.
apply(
    "git/video_player-*/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayerPlugin.java",
    [(
        """  @SuppressWarnings("deprecation")
  private VideoPlayerPlugin(io.flutter.plugin.common.PluginRegistry.Registrar registrar) {
    this.flutterState =
        new FlutterState(
            registrar.context(),
            registrar.messenger(),
            registrar::lookupKeyForAsset,
            registrar::lookupKeyForAsset,
            registrar.textures());
    flutterState.startListening(this, registrar.messenger());
  }

""",
        "",
    )],
)

# 2) file_picker: widen setup() param and drop the v1 branch.
apply(
    "hosted/pub.dev/file_picker-*/android/src/main/java/com/mr/flutter/plugin/filepicker/FilePickerPlugin.java",
    PARAM_TYPE + [(
        """        this.observer = new LifeCycleObserver(activity);
        if (registrar != null) {
            // V1 embedding setup for activity listeners.
            application.registerActivityLifecycleCallbacks(this.observer);
            registrar.addActivityResultListener(this.delegate);
            registrar.addRequestPermissionsResultListener(this.delegate);
        } else {
            // V2 embedding setup for activity listeners.
            activityBinding.addActivityResultListener(this.delegate);
            activityBinding.addRequestPermissionsResultListener(this.delegate);
            this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
            this.lifecycle.addObserver(this.observer);
        }""",
        """        this.observer = new LifeCycleObserver(activity);
        // V2 embedding setup for activity listeners.
        activityBinding.addActivityResultListener(this.delegate);
        activityBinding.addRequestPermissionsResultListener(this.delegate);
        this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
        this.lifecycle.addObserver(this.observer);""",
    )],
)

# 3) ffmpeg_kit_flutter_audio: widen init() param and drop the v1 branch.
apply(
    "hosted/pub.dev/ffmpeg_kit_flutter_audio-*/android/src/main/java/com/arthenica/ffmpegkit/flutter/FFmpegKitFlutterPlugin.java",
    PARAM_TYPE + [(
        """        if (registrar != null) {
            // V1 embedding setup for activity listeners.
            registrar.addActivityResultListener(this);
        } else {
            // V2 embedding setup for activity listeners.
            activityBinding.addActivityResultListener(this);
        }""",
        """        // V2 embedding setup for activity listeners.
        activityBinding.addActivityResultListener(this);""",
    )],
)

# 4) image_picker_android: widen both params and drop the v1 branch.
apply(
    "hosted/pub.dev/image_picker_android-*/android/src/main/java/io/flutter/plugins/imagepicker/ImagePickerPlugin.java",
    PARAM_TYPE + [(
        """      observer = new LifeCycleObserver(activity);
      if (registrar != null) {
        // V1 embedding setup for activity listeners.
        application.registerActivityLifecycleCallbacks(observer);
        registrar.addActivityResultListener(delegate);
        registrar.addRequestPermissionsResultListener(delegate);
      } else {
        // V2 embedding setup for activity listeners.
        activityBinding.addActivityResultListener(delegate);
        activityBinding.addRequestPermissionsResultListener(delegate);
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
        lifecycle.addObserver(observer);
      }""",
        """      observer = new LifeCycleObserver(activity);
      // V2 embedding setup for activity listeners.
      activityBinding.addActivityResultListener(delegate);
      activityBinding.addRequestPermissionsResultListener(delegate);
      lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
      lifecycle.addObserver(observer);""",
    )],
)

# 5) flutter_inappwebview: v1 `registrar` field plus its two usages, and the
#    removed v1 `io.flutter.view.FlutterView` (a plain View works: it is only
#    forwarded to InAppWebView's `View containerView` parameter).
apply(
    "hosted/pub.dev/flutter_inappwebview-*/android/src/main/java/com/pichillilorenzo/flutter_inappwebview/InAppWebViewFlutterPlugin.java",
    [
        ("  public PluginRegistry.Registrar registrar;\n", ""),
        ("import io.flutter.view.FlutterView;\n", ""),
        ("  public FlutterView flutterView;", "  public android.view.View flutterView;"),
        (
            "PlatformViewRegistry platformViewRegistry, FlutterView flutterView) {",
            "PlatformViewRegistry platformViewRegistry, android.view.View flutterView) {",
        ),
    ],
)
apply(
    "hosted/pub.dev/flutter_inappwebview-*/android/src/main/java/com/pichillilorenzo/flutter_inappwebview/Util.java",
    [(
        "String key = (plugin.registrar != null) ? plugin.registrar.lookupKeyForAsset(assetFilePath) : plugin.flutterAssets.getAssetFilePathByName(assetFilePath);",
        "String key = plugin.flutterAssets.getAssetFilePathByName(assetFilePath);",
    )],
)
apply(
    "hosted/pub.dev/flutter_inappwebview-*/android/src/main/java/com/pichillilorenzo/flutter_inappwebview/in_app_webview/InAppWebViewChromeClient.java",
    [(
        """    if (plugin.registrar != null)
      plugin.registrar.addActivityResultListener(this);
    else if (plugin.activityPluginBinding != null)
      plugin.activityPluginBinding.addActivityResultListener(this);""",
        """    if (plugin.activityPluginBinding != null)
      plugin.activityPluginBinding.addActivityResultListener(this);""",
    )],
)

# 6) permission_handler_android: v1 field + v1 branch in registerListeners.
apply(
    "hosted/pub.dev/permission_handler_android-*/android/src/main/java/com/baseflow/permissionhandler/PermissionHandlerPlugin.java",
    [
        (
            """    @SuppressWarnings("deprecation")
    @Nullable private io.flutter.plugin.common.PluginRegistry.Registrar pluginRegistrar;

""",
            "",
        ),
        (
            """        if (this.pluginRegistrar != null) {
            this.pluginRegistrar.addActivityResultListener(this.permissionManager);
            this.pluginRegistrar.addRequestPermissionsResultListener(this.permissionManager);
        } else if (pluginBinding != null) {
            this.pluginBinding.addActivityResultListener(this.permissionManager);
            this.pluginBinding.addRequestPermissionsResultListener(this.permissionManager);
        }""",
            """        if (pluginBinding != null) {
            this.pluginBinding.addActivityResultListener(this.permissionManager);
            this.pluginBinding.addRequestPermissionsResultListener(this.permissionManager);
        }""",
        ),
    ],
)

# 7) sensors_plus: getDefaultSensor() is now nullable (Sensor?) on newer SDKs.
apply(
    "hosted/pub.dev/sensors_plus-*/android/src/main/kotlin/dev/fluttercommunity/plus/sensors/StreamHandlerImpl.kt",
    [("private val sensor: Sensor by lazy {", "private val sensor: Sensor? by lazy {")],
)

sys.exit(0)

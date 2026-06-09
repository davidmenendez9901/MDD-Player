import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:songtube/internal/network/network_manager.dart';
import 'package:songtube/providers/app_settings.dart';

/// HTTP service that refuses to go out to the network in offline mode:
/// cached images still load from disk, uncached ones fail fast without
/// any outgoing request
class _OfflineAwareFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    NetworkManager.ensureOnline();
    return super.get(url, headers: headers);
  }
}

/// Shared cache manager for every network image in the app
final CacheManager stImageCacheManager = CacheManager(
  Config(
    'stImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 2000,
    fileService: _OfflineAwareFileService(),
  ),
);

/// Drop-in replacement for [NetworkImage]: disk cached, offline safe and
/// thumbnail-degrading under data saver. Use everywhere an [ImageProvider]
/// is needed
ImageProvider stImageProvider(String url) {
  return CachedNetworkImageProvider(
    STNetworkImage.lowRes(url),
    cacheManager: stImageCacheManager,
  );
}

/// Network image with disk cache and offline awareness.
///
/// - Images are fetched once and served from disk afterwards.
/// - In offline mode no request ever leaves the device: the image is shown
///   only if it is already cached, otherwise [placeholder] is rendered.
/// - Under data saver / audio-only mode YouTube thumbnails are degraded to
///   a lighter resolution via [lowRes].
class STNetworkImage extends StatelessWidget {
  const STNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;

  static CacheManager get cacheManager => stImageCacheManager;

  /// Degrade a YouTube thumbnail URL to medium quality when the user wants
  /// to save data. YouTube serves the same thumbnail at several fixed
  /// resolutions (maxresdefault ~100-300KB vs mqdefault ~10-20KB)
  static String lowRes(String url) {
    if (!AppSettings.dataSaverMode && !AppSettings.audioOnlyMode) {
      return url;
    }
    if (url.contains('ytimg.com') || url.contains('img.youtube.com')) {
      return url
        .replaceAll('maxresdefault', 'mqdefault')
        .replaceAll('sddefault', 'mqdefault')
        .replaceAll('hqdefault', 'mqdefault');
    }
    return url;
  }

  /// Cache-aware [ImageProvider] for consumers that need one (palette
  /// generation, ImageFade...). Returns null when offline and not cached,
  /// so callers can skip work instead of triggering a network fetch
  static Future<ImageProvider?> provider(String? url) async {
    if (url == null || url.isEmpty) {
      return null;
    }
    final target = lowRes(url);
    final cached = await cacheManager.getFileFromCache(target);
    if (cached != null) {
      return FileImage(cached.file);
    }
    if (NetworkManager.isOffline) {
      return null;
    }
    return CachedNetworkImageProvider(target, cacheManager: cacheManager);
  }

  Widget _placeholder(BuildContext context) {
    return placeholder ?? Container(color: Theme.of(context).cardColor);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholder(context);
    }
    final target = lowRes(imageUrl);
    if (NetworkManager.isOffline) {
      // Offline: serve from cache only, never reach the network
      return FutureBuilder<FileInfo?>(
        future: cacheManager.getFileFromCache(target),
        builder: (context, snapshot) {
          final file = snapshot.data?.file;
          if (file == null) {
            return _placeholder(context);
          }
          return Image.file(File(file.path), fit: fit, width: width, height: height);
        },
      );
    }
    return CachedNetworkImage(
      cacheManager: cacheManager,
      imageUrl: target,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, _) => _placeholder(context),
      errorWidget: (context, _, __) => _placeholder(context),
    );
  }
}

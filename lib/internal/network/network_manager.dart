import 'package:songtube/providers/app_settings.dart';

/// Thrown by network paths when the user enabled offline mode
class OfflineModeException implements Exception {
  final String message;
  OfflineModeException([this.message = 'La app está en modo offline']);
  @override
  String toString() => 'OfflineModeException: $message';
}

/// Central gate for every outgoing network call. The offline switch is
/// fully manual (no connectivity plugin): the user decides when the app
/// is allowed to use the network.
class NetworkManager {
  NetworkManager._();

  /// true if the user enabled offline mode
  static bool get isOffline => AppSettings.offlineMode;

  /// true if outgoing connections are allowed
  static bool get canConnect => !AppSettings.offlineMode;

  /// Throws [OfflineModeException] when offline. Call at the start of any
  /// network-reaching method
  static void ensureOnline() {
    if (isOffline) {
      throw OfflineModeException();
    }
  }
}

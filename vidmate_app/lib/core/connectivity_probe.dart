import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Zero-dependency (uses the already-included `dio` package) network
/// connectivity detection.
///
/// Probes a reliable public host over plain HTTP GET with a short timeout.
/// Works **identically on mobile and web** because `dio` abstracts the
/// underlying transport (it uses `dart:io` on native, `dart:html` on web),
/// unlike a raw `dart:io` socket which throws `UnsupportedError` on web.
///
/// This lets the app detect its **own** online/offline state WITHOUT adding
/// the `connectivity_plus` package to pubspec.yaml.
class ConnectivityProbe {
  /// Reliable, cheap canary that returns a small response quickly.
  static const String _canaryUrl = 'https://example.com';
  static const Duration _timeout = Duration(seconds: 5);

  static final Dio _probeDio = Dio(BaseOptions(
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
  ));

  /// True if the device appears to have internet access.
  ///
  /// Returns `false` on any network error / timeout so the caller can fall
  /// back to offline mock data. Intentionally broad: any connectivity
  /// failure counts as "offline".
  static Future<bool> hasInternetAccess() async {
    try {
      debugPrint('CONNECTIVITY: probing $_canaryUrl ...');
      final response = await _probeDio.get(_canaryUrl);
      debugPrint(
        'CONNECTIVITY: response=${response.statusCode}, reachable=${response.statusCode! < 500}',
      );
      // Any HTTP response (even a non-2xx) means the network path works.
      return response.statusCode != null;
    } on TimeoutException {
      debugPrint('CONNECTIVITY: timeout -> offline');
      return false;
    } catch (e) {
      // Dio wraps network errors (SocketException, TimeoutException, etc.)
      // in DioException, or throws a raw TimeoutException on timeout.
      final isTimeout = e is TimeoutException;
      debugPrint(
        'CONNECTIVITY: ${isTimeout ? "timeout" : "error"} -> offline ($e)',
      );
      return false;
    }
  }
}

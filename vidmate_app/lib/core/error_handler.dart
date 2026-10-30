import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// Central error handler for VidiMate app
/// Converts technical errors into user-friendly messages
class ErrorHandler {
  /// Get a friendly message from an exception/error
  static String getFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }

    if (error is Exception || error is Error) {
      final errorStr = error.toString().toLowerCase();

      if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket') ||
          errorStr.contains('host')) {
        return 'Internet connection nahi mil raha. Apna Wi-Fi ya mobile data check karein.';
      }

      if (errorStr.contains('timeout')) {
        return 'Request time out ho gaya. Apna internet check karein aur dobara try karein.';
      }

      if (errorStr.contains('permission')) {
        return 'App ko file save karne ke liye permission chahiye.';
      }

      if (errorStr.contains('storage') || errorStr.contains('space')) {
        return 'Phone mein jagah kam hai. Kuch files delete karke dobara try karein.';
      }
    }

    // Unknown error
    return 'Kuch ghalat ho gaya. Dobara try karein.';
  }

  /// Get a specific error type for UI customization
  static ErrorType getErrorType(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return ErrorType.timeout;
        case DioExceptionType.connectionError:
          return ErrorType.network;
        case DioExceptionType.badResponse:
          return ErrorType.server;
        default:
          return ErrorType.unknown;
      }
    }

    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('socket')) {
      return ErrorType.network;
    }
    if (errorStr.contains('timeout')) {
      return ErrorType.timeout;
    }
    if (errorStr.contains('permission')) {
      return ErrorType.permission;
    }
    if (errorStr.contains('storage') || errorStr.contains('space')) {
      return ErrorType.storage;
    }

    return ErrorType.unknown;
  }

  /// Handle Dio-specific errors
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Request time out ho gaya. Apna internet check karein aur dobara try karein.';

      case DioExceptionType.connectionError:
        return 'Internet connection nahi mil raha. Apna Wi-Fi ya mobile data check karein.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 500) {
            return 'Server abhi available nahi hai. Thodi dair baad try karein.';
          } else if (statusCode >= 400) {
            return 'Request valid nahi hai. Thodi dair baad try karein.';
          }
        }
        return 'Server abhi available nahi hai. Thodi dair baad try karein.';

      case DioExceptionType.unknown:
        return 'Internet connection nahi mil raha. Apna Wi-Fi ya mobile data check karein.';

      default:
        return 'Kuch ghalat ho gaya. Dobara try karein.';
    }
  }

  /// Log error for developers (not shown to users)
  static void logError(dynamic error, {StackTrace? stackTrace}) {
    debugPrint('ERROR: ${error.toString()}');
    if (stackTrace != null) {
      debugPrint('STACK TRACE: ${stackTrace.toString()}');
    }
  }
}

/// Types of errors that can occur
enum ErrorType {
  network,
  timeout,
  server,
  permission,
  storage,
  unknown,
}

/// Get a friendly icon for error type
IconData getErrorIcon(ErrorType type) {
  switch (type) {
    case ErrorType.network:
      return Icons.wifi_off;
    case ErrorType.timeout:
      return Icons.watch_later;
    case ErrorType.server:
      return Icons.error_outline;
    case ErrorType.permission:
      return Icons.lock_outline;
    case ErrorType.storage:
      return Icons.storage;
    case ErrorType.unknown:
      return Icons.error;
  }
}

/// Get an error title for display
String getErrorTitle(ErrorType type) {
  switch (type) {
    case ErrorType.network:
      return 'No Internet Connection';
    case ErrorType.timeout:
      return 'Request Timeout';
    case ErrorType.server:
      return 'Server Error';
    case ErrorType.permission:
      return 'Permission Required';
    case ErrorType.storage:
      return 'Storage Full';
    case ErrorType.unknown:
      return 'Something Went Wrong';
  }
}

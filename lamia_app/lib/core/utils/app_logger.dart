import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized application logger for La Mia.
///
/// Wraps [Logger] to provide structured, colorized, and tagged terminal
/// logging during development while automatically reporting errors to
/// [FirebaseCrashlytics] in production.
class AppLogger {
  AppLogger._();

  static final Logger _instance = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  /// Log detailed debug information (e.g. state changes, internal variables).
  static void debug(String message, [String? category]) {
    final formatted = category != null ? '[$category] $message' : message;
    _instance.d(formatted);
  }

  /// Log key operational events (e.g. successful login, screen navigation).
  static void info(String message, [String? category]) {
    final formatted = category != null ? '[$category] $message' : message;
    _instance.i(formatted);
    _logCrashlytics(formatted);
  }

  /// Log non-fatal issues or warnings (e.g. fallback values, retries).
  static void warning(String message, [String? category]) {
    final formatted = category != null ? '[$category] $message' : message;
    _instance.w(formatted);
    _logCrashlytics(formatted);
  }

  /// Log unexpected exceptions or failures.
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? category,
    bool fatal = false,
  }) {
    final formatted = category != null ? '[$category] $message' : message;
    _instance.e(formatted, error: error, stackTrace: stackTrace);

    try {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: formatted,
        fatal: fatal,
      );
    } catch (_) {
      // Ignored in unit tests where Firebase is uninitialized.
    }
  }

  static void _logCrashlytics(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // Ignored in unit tests where Firebase is uninitialized.
    }
  }
}

import 'package:logger/logger.dart';

/// An adapter to set [Logger] for this package
///
/// [Logger]:(https://pub.dev/packages/logger)
class AnalyticsLogAdapter {
  AnalyticsLogAdapter._privateConstructor();
  static AnalyticsLogAdapter shared = AnalyticsLogAdapter._privateConstructor();

  /// Logger instance to write log, must be set before using
  Logger logger;
}

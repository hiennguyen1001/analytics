library analytics;

import 'package:analytics/analytic_log_adapter.dart';

export 'package:analytics/outputs/active_campaign_output.dart';
export 'analytic_log_adapter.dart';
export 'package:analytics/outputs/mix_panel_output.dart';

/// Analytics output abstract class
abstract class AnalyticsOutput {
  /// Send even tracking
  ///
  /// `name` event name
  ///
  /// `info` the event data
  Future<void> sendEvent(String name, dynamic info);

  /// Send user properties
  ///
  /// `info` user properties
  Future<void> sendUserProperty(Map info);

  /// Set user id for service
  Future<void> setUserId(String value);

  /// Get the analytics name
  String get name;
}

/// Analytics class
class Analytics {
  Analytics._privateConstructor();
  static Analytics shared = Analytics._privateConstructor();
  final List<AnalyticsOutput> _outputs = [];

  /// Add the analytics outputs
  void addOutput(dynamic output) {
    if (output is List<AnalyticsOutput>) {
      _outputs.addAll(output);
    } else if (output is AnalyticsOutput) {
      _outputs.add(output);
    }
  }

  /// Loop through all outputs to send analytics events
  /// If an `outputTarget` is specified, then just use that kind output
  Future<void> sendEvent(String name, dynamic info,
      {String outputTarget}) async {
    for (final output in _outputs) {
      if (outputTarget != null) {
        // if there is an output target, then just run it & ignore the rest
        if (outputTarget == output.name) {
          try {
            await output.sendEvent(name, info);
          } catch (e, stacktrace) {
            AnalyticsLogAdapter.shared.logger
                ?.e('Send event error', e, stacktrace);
          }
        }
      } else {
        try {
          await output.sendEvent(name, info);
        } catch (e, stacktrace) {
          AnalyticsLogAdapter.shared.logger
              ?.e('Send event error', e, stacktrace);
        }
      }
    }
  }

  /// Loop through all outputs to send user properties
  /// If an `outputTarget` is specified, then just use that kind output
  Future<void> sendUserProperty(Map info, {String outputTarget}) async {
    for (final output in _outputs) {
      if (outputTarget != null) {
        // if there is an output target, then just run it & ignore the rest
        if (outputTarget == output.name) {
          try {
            await output.sendUserProperty(info);
          } catch (e, stacktrace) {
            AnalyticsLogAdapter.shared.logger
                ?.e('Send property error', e, stacktrace);
          }
        }
      } else {
        try {
          await output.sendUserProperty(info);
        } catch (e, stacktrace) {
          AnalyticsLogAdapter.shared.logger
              ?.e('Send property error', e, stacktrace);
        }
      }
    }
  }

  /// Set user id for all outputs
  Future<void> setUserId(String value) async {
    for (final output in _outputs) {
      await output.setUserId(value);
    }
  }
}

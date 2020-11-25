library analytics;

export 'package:analytics/outputs/active_campaign_output.dart';
export 'package:analytics/outputs/mix_panel_output.dart';
import 'package:logger/logger.dart';

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

enum OutputType { mixPanel, activeCampaign, firebase }

extension $OutputType on OutputType {
  static final typeString = {
    OutputType.mixPanel: 'mixPanel',
    OutputType.activeCampaign: 'activeCampaign',
    OutputType.firebase: 'firebase',
  };

  static final outputEnum = {
    'mixPanel': OutputType.mixPanel,
    'activeCampaign': OutputType.activeCampaign,
    'firebase': OutputType.firebase,
  };

  String get name => $OutputType.typeString[this];
  static OutputType fromString(String value) => $OutputType.outputEnum[value];
}

/// Analytics class
class Analytics {
  Analytics._privateConstructor();
  static Analytics shared = Analytics._privateConstructor();
  final List<AnalyticsOutput> outputs = [];
  Logger logger;

  static void init(Logger logger) {
    shared.logger = logger;
  }

  /// Add the analytics outputs
  void addOutput(dynamic output) {
    if (output is List<AnalyticsOutput>) {
      outputs.addAll(output);
    } else if (output is AnalyticsOutput) {
      outputs.add(output);
    }
  }

  /// Loop through all outputs to send analytics events
  /// Using `eventMapper` to send for special output target
  ///
  /// eg.
  /// ```
  /// {'MixPanelOutput': 'value a', 'FirebaseOutput': 'value b'}
  /// ```
  Future<void> sendEvent(String name,
      {Map<OutputType, dynamic> mapper, dynamic info}) async {
    if (mapper != null) {
      for (var item in mapper.entries) {
        var output = outputs.firstWhere(
            (element) => element.name == item.key.name,
            orElse: () => null);
        if (output != null) {
          try {
            var data = item.value;
            await output.sendEvent(name, data);
          } catch (e, stacktrace) {
            logger?.e('[${output.name}] Send event error', e, stacktrace);
          }
        }
      }
    } else if (info != null) {
      for (final output in outputs) {
        try {
          await output.sendEvent(name, info);
        } catch (e, stacktrace) {
          logger?.e('[${output.name}] Send event error', e, stacktrace);
        }
      }
    }
  }

  /// Loop through all outputs to send user properties
  /// Using `mapper` to send for special output target
  ///
  /// eg.
  /// ```
  /// {'MixPanelOutput': 'value a', 'FirebaseOutput': 'value b'}
  /// ```
  Future<void> sendUserProperty({Map info, Map<OutputType, Map> mapper}) async {
    if (mapper != null) {
      for (var entry in mapper.entries) {
        var output = outputs.firstWhere(
            (element) => element.name == entry.key.name,
            orElse: () => null);
        if (output != null) {
          try {
            var data = entry.value;
            await output.sendUserProperty(data);
          } catch (e, stacktrace) {
            logger?.e('[${output.name}] Send property error $e', e, stacktrace);
          }
        }
      }
    } else if (info != null) {
      for (final output in outputs) {
        try {
          await output.sendUserProperty(info);
        } catch (e, stacktrace) {
          logger?.e('[${output.name}] Send property error $e', e, stacktrace);
        }
      }
    }
  }

  /// Set user id for all outputs
  Future<void> setUserId(String value) async {
    for (final output in outputs) {
      await output.setUserId(value);
    }
  }
}

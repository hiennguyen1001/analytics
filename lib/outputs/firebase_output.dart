import 'package:analytics/analytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseOutput extends AnalyticsOutput {
  static final analytics = FirebaseAnalytics.instance;
  static final observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  String get name => 'firebase';

  @override
  Future<void> sendEvent(String name, dynamic info) async {
    var params = Map<String, Object>.from(info);
    await analytics.logEvent(name: name, parameters: params);
  }

  @override
  Future<void> sendUserProperty(Map info) async {
    for (var key in info.keys) {
      await analytics.setUserProperty(name: key, value: info[key]);
    }
  }

  @override
  Future<void> setUserId(String value) async {
    await analytics.setUserId(id: value);
  }
}

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../mixpanel_analytics.dart';

class MixPanelOutput extends AnalyticsOutput {
  MixPanelOutput(Map configs, {String? id}) {
    _mixpanel = MixpanelAnalytics(
        token: configs['mixpanelId'],
        proxyUrl: configs['crossOriginUrl'],
        userId$: _user$.stream,
        optionalHeaders: {
          'X-Requested-With': 'XMLHttpRequest'
        },
        verbose: true,
        shouldAnonymize: true,
        shaFn: (value) => value,
        onError: (e) {});

    if (id != null) {
      setUserId(id);
    }
  }

  static const String _userIdKey = 'mixpanel_user_id';

  late MixpanelAnalytics _mixpanel;
  SharedPreferences? _prefs;
  final _user$ = StreamController<String>.broadcast();

  @override
  String get name => 'mixPanel';

  @override
  Future<void> sendEvent(String name, dynamic properties) async {
    await _sendEvent(name, properties);
  }

  @override
  Future<void> sendUserProperty(Map info) async {
    await _sendUserProperty(info);
  }

  Future<SharedPreferences?> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs;
  }

  Future<String> get _mixpanelUserId async {
    var id = (await prefs)!.getString(_userIdKey);
    if (id == null) {
      id = Uuid().v4();
      await (await prefs)!.setString(_userIdKey, id);
    }

    return id;
  }

  @override
  Future<void> setUserId(String id) async {
    var oldId = await _mixpanelUserId;
    // only migrate if id is changed
    if (oldId != id) {
      // migrate cognito user id into guest id
      var properties = <String, dynamic>{};
      properties['\$identified_id'] = id;
      properties['\$anon_id'] = oldId;
      await _mixpanel
          .track(event: '\$identify', properties: properties)
          .then((value) async {
        Analytics.shared.logger?.i('merge [$oldId, $id] $value');
        await (await prefs)!.setString(_userIdKey, id);
      }).catchError((e, stacktrace) {
        Analytics.shared.logger
            ?.e('merge [$oldId, $id] error: $e', error: e, stackTrace: stacktrace);
      });
    }
  }

  Future<void> _sendUserProperty(Map info) async {
    for (var key in info.keys) {
      var propertyName = key;
      var propertyValue = info[key];

      await _mixpanel.engage(
          operation: MixpanelUpdateOperations.$set,
          value: <String, dynamic>{
            propertyName: propertyValue,
            'distinct_id': await _mixpanelUserId,
          }).then((value) {
        Analytics.shared.logger?.i('trackUserProperty $value');
      }).catchError((e, stacktrace) {
        Analytics.shared.logger
            ?.e('trackUserProperty error: $e', error: e, stackTrace: stacktrace);
      });
    }
  }

  Future<void> _sendEvent(String event, dynamic properties) async {
    properties['distinct_id'] = await _mixpanelUserId;

    await _mixpanel
        .track(event: event, properties: Map<String, dynamic>.from(properties))
        .then((value) {
      Analytics.shared.logger?.i('sendEvent $value');
    }).catchError((e, stacktrace) {
      Analytics.shared.logger?.e('sendEvent error: $e', error: e, stackTrace: stacktrace);
    });
  }
}

import 'dart:convert';

import 'package:analytics/analytic_log_adapter.dart';
import 'package:analytics/analytics.dart';
import 'package:robust_http/robust_http.dart';

/// An output to send tracking event into actice campaign.
class ActiveCampaignOutput extends AnalyticsOutput {
  /// AC http api client
  HTTP _http;

  /// AC tracking http client
  HTTP _trackingHttp;

  /// Event tracking url
  String _eventUrl;

  /// Base api url
  String _baseUrl;

  /// Proxy url
  String _proxyUrl;

  /// whether to include http prefix
  bool _enableHttp;

  /// AC event key
  String _eventKey;

  /// AC event act id
  String _eventActid;

  /// User email
  String _email;

  /// Use first name
  String _firstName;

  /// User last name
  String _lastName;

  /// Suffix url
  String _suffixUrl;

  /// Initialize output
  ///
  /// `email`: user email
  ///
  /// `firstName`: user first name (optional)
  ///
  /// `lastName`: user last name (optional)
  ///
  /// The `config` requires these parameters:
  ///
  /// `proxyUrl`: the proxy server to bypass CORS for web
  ///
  /// `enableHttp`: whether to include http in url or not
  ///
  /// `activeCampaignAccount`: ac account name
  ///
  /// `activeCampaignKey`: ac key
  ///
  /// `activeCampaignEventKey`: ac event key
  ///
  /// `activeCampaignEventActid`: ac event act id
  ActiveCampaignOutput(String email, Map config,
      {String firstName, String lastName}) {
    _firstName = firstName;
    _lastName = lastName;
    _email = email;
    _proxyUrl = config["proxyUrl"];
    _enableHttp = config["enableHttp"] ?? true;
    _suffixUrl = _proxyUrl != null && !_proxyUrl.endsWith('/') ? '/' : '';

    if (_enableHttp == true) {
      _baseUrl =
          'https://${config["activeCampaignAccount"]}.api-us1.com/api/3/';
    } else {
      _baseUrl = '${config["activeCampaignAccount"]}.api-us1.com/api/3/';
    }

    if (_proxyUrl != null) {
      _http = HTTP(null, config);
    } else {
      _http = HTTP(_baseUrl, config);
    }

    _http.headers = {"Api-Token": config['activeCampaignKey']};

    _eventKey = config["activeCampaignEventKey"];
    _eventActid = config["activeCampaignEventActid"];

    // init for event tracking http
    if (_proxyUrl != null) {
      if (_enableHttp) {
        _eventUrl = _proxyUrl + _suffixUrl + 'https://trackcmp.net/';
      } else {
        _eventUrl = _proxyUrl + _suffixUrl + 'trackcmp.net/';
      }

      _trackingHttp = HTTP(null, config);
    } else {
      _eventUrl = '';
      _trackingHttp = HTTP('https://trackcmp.net/', config);
    }

    _trackingHttp.dio.options.contentType = 'application/x-www-form-urlencoded';

    if (_firstName == null) {
      _firstName = email.substring(0, email.indexOf('@'));
    }

    if (_lastName == null) {
      _lastName = '';
    }
  }

  @override
  void sendEvent(String name, dynamic info) {
    String eventData;
    if (info is String) {
      eventData = info;
    } else {
      eventData = jsonEncode(info);
    }

    _trackEvent(name, _email, eventData)
        .then((value) => null)
        .catchError((e, stacktrace) {
      AnalyticsLogAdapter.shared.logger?.e('Send event error', e, stacktrace);
    });
  }

  @override
  void sendUserProperty(Map info) {
    _updateProperties(_email,
            firstName: _firstName, lastName: _lastName, properties: info)
        .then((value) => null)
        .catchError((e, stacktrace) {
      AnalyticsLogAdapter.shared.logger
          ?.e('Send property error', e, stacktrace);
    });
  }

  /// Get the url if using proxy
  get _url {
    if (_proxyUrl != null) {
      return _proxyUrl + _suffixUrl + _baseUrl;
    }

    return '';
  }

  /// Update AC user properties (custom properties)
  Future<dynamic> _updateProperties(String email,
      {String firstName,
      String lastName,
      Map properties,
      bool forceUpdated = false}) async {
    if (properties == null) {
      return null;
    }
    var contact = await _createContact(email,
        firstName: firstName, lastName: lastName, forceUpdated: forceUpdated);
    if (contact == null || contact['id'] == null) {
      return null;
    }

    var contactId = contact['id'];
    var response = await _http.get("${_url}fields");
    if (response['fields'] != null && response['fields'].isNotEmpty) {
      for (var property in properties.entries) {
        String fieldId;
        for (var field in response['fields']) {
          if (property.key == field['title']) {
            fieldId = field['id'];
            break;
          }
        }

        if (fieldId == null) {
          // create custom field
          fieldId = await _createField(property.key);
        }

        // Update field value
        await _updateField(contactId, fieldId, property.value);
      }
    } else {
      for (var property in properties.entries) {
        // create custom field
        var fieldId = await _createField(property.key);
        // Update field value
        await _updateField(contactId, fieldId, property.value);
      }
    }

    return null;
  }

  /// Update AC custom field with value
  Future<dynamic> _updateField(
      String contactId, String fieldId, dynamic value) async {
    var body = """
          {
            "fieldValue": {
                "contact": $contactId,
                "field": $fieldId,
                "value": "$value"
            }
          }
          """;

    await _http.post("${_url}fieldValues", data: body);
  }

  /// Create AC custom field
  Future<dynamic> _createField(String key) async {
    var body = """
          {
            "field": {
              "type": "text",
              "title": "$key",
              "descript": "$key",
              "visible": 1
            }
          }
          """;
    var res = await _http.post("${_url}fields", data: body);
    return res['field']['id'];
  }

  /// Create contact if not exist
  /// Return a contact object
  Future<dynamic> _createContact(String email,
      {String firstName, String lastName, bool forceUpdated = false}) async {
    var contact;
    // get contact by email
    var params = {'email': email};
    var response = await _http.get("${_url}contacts", parameters: params);
    if (response['contacts'] != null) {
      List contacts = response['contacts'];
      contact = contacts.firstWhere((item) => item['email'] == email,
          orElse: () => null);
    }

    if (contact == null || forceUpdated == true) {
      // create new contact
      var body = """
        {
          "contact": {
            "email": "$email",
            "firstName": "$firstName",
            "lastName": "$lastName"
          }
        }
        """;
      var response = await _http.post('${_url}contact/sync', data: body);
      if (response['contact'] != null) {
        return response['contact'];
      }
    }

    return contact;
  }

  /// Send tracking event
  Future<dynamic> _trackEvent(
      String eventName, String email, String eventData) async {
    var visit = '{"email" : "$email"}';
    var params = {
      'key': _eventKey,
      'event': eventName,
      'eventdata': eventData,
      'actid': _eventActid,
      'visit': visit
    };

    return await _trackingHttp.post('${_eventUrl}event', data: params);
  }
}

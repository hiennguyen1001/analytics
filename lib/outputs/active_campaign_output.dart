import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:robust_http/robust_http.dart';

/// An output to send tracking event into actice campaign.
class ActiveCampaignOutput extends AnalyticsOutput {
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
  ///
  /// `tags`: user tags
  ActiveCampaignOutput(
    String email,
    Map config, {
    String firstName,
    String lastName,
    List<String> tags,
  }) {
    _tags = tags ?? <String>[];
    this.firstName = firstName;
    this.lastName = lastName;
    _email = email;
    _proxyUrl = config['proxyUrl'];
    _enableHttp = config['enableHttp'] ?? true;
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

    _http.headers = {'Api-Token': config['activeCampaignKey']};

    _eventKey = config['activeCampaignEventKey'];
    _eventActid = config['activeCampaignEventActid'];

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
    _trackingHttp.headers = {'content-type': 'application/x-www-form-urlencoded'};

    this.firstName ??= email.substring(0, email.indexOf('@'));
    this.lastName ??= '';

    if (config.containsKey('nameProperties')) {
      _nameProperties = config['nameProperties'];
    }
  }

  /// Base api url
  String _baseUrl;

  /// User email
  String _email;

  /// whether to include http prefix
  bool _enableHttp;

  /// AC event act id
  String _eventActid;

  /// AC event key
  String _eventKey;

  /// Event tracking url
  String _eventUrl;

  /// Use first name
  String firstName;

  /// AC http api client
  HTTP _http;

  /// User last name
  String lastName;

  /// Proxy url
  String _proxyUrl;

  /// Suffix url
  String _suffixUrl;

  /// AC tracking http client
  HTTP _trackingHttp;

  /// User tags to add to contact
  List<String> _tags;

  /// User contact id
  String _contactId;

  /// Name property fields
  List _nameProperties = [];

  @override
  String get name => 'activeCampaign';

  @override
  Future<void> sendEvent(String name, dynamic info) async {
    String eventData;
    if (info is String) {
      eventData = info;
    } else {
      eventData = jsonEncode(info);
    }

    await _trackEvent(name, _email, eventData);
  }

  @override
  Future<void> sendUserProperty(Map info) async {
    await _updateProperties(_email,
        firstName: firstName, lastName: lastName, properties: info);
  }

  @override
  Future<void> setUserId(String value) async {}

  /// Get the url if using proxy
  String get _url {
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

    for (var p in _nameProperties) {
      if (properties.containsKey(p)) {
        forceUpdated = true;
        break;
      }
    }

    var contactId = await _createContact(email,
        firstName: firstName, lastName: lastName, forceUpdated: forceUpdated);
    if (contactId == null) {
      return null;
    }

    var fields = await _listFields();
    Analytics.shared.logger?.i('existing fields: [${fields.length}]');
    if (fields.isNotEmpty) {
      for (var property in properties.entries) {
        String fieldId;
        for (var field in fields) {
          if (property.key == field['title']) {
            fieldId = field['id'];
            break;
          }
        }

        fieldId ??= await _createField(property.key);

        Analytics.shared.logger?.i(
            'update value ${property.value} for field $fieldId in contact $contactId');
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

  Future<dynamic> _listFields() async {
    var fields = [];
    var offset = 0;
    var totalFields = 0;
    final maxPage = 100;

    do {
      var response =
          await _http.get('${_url}fields?limit=$maxPage&offset=$offset');
      fields.addAll(response['fields']);
      totalFields = int.parse(response['meta']['total']);
      offset += maxPage;
      Analytics.shared.logger
          ?.i('_listFields offset = $offset, totalFields = $totalFields');
    } while (offset < totalFields);

    return fields;
  }

  /// Update AC custom field with value
  Future<dynamic> _updateField(
      String contactId, String fieldId, dynamic value) async {
    if (value is String) {
      value = value.replaceAll('"', '\\"');
    }

    var body = '''
          {
            "fieldValue": {
                "contact": $contactId,
                "field": $fieldId,
                "value": "$value"
            }
          }
          ''';

    await _http.post('${_url}fieldValues', data: body);
  }

  /// Create AC custom field
  Future<dynamic> _createField(String key) async {
    var body = '''
          {
            "field": {
              "type": "text",
              "title": "$key",
              "descript": "$key",
              "visible": 1
            }
          }
          ''';
    var res = await _http.post('${_url}fields', data: body);
    return res['field']['id'];
  }

  Future<dynamic> createContact() async {
    await _createContact(_email,
        firstName: firstName, lastName: lastName, forceUpdated: false);
  }

  /// Create contact if not exist
  /// Return a contact id
  Future<dynamic> _createContact(String email,
      {String firstName, String lastName, bool forceUpdated = false}) async {
    if (!forceUpdated && _contactId != null && _contactId.isNotEmpty) {
      return _contactId;
    }

    var contact;
    // get contact by email
    var params = {'email': email};
    var response = await _http.get('${_url}contacts', parameters: params);
    if (response['contacts'] != null) {
      List contacts = response['contacts'];
      contact = contacts.firstWhere(
          (item) => item['email'].replaceAll(' ', '+') == email,
          orElse: () => null);
    }

    if (contact == null || forceUpdated == true) {
      // create new contact
      var body = '''
        {
          "contact": {
            "email": "$email",
            "firstName": "$firstName",
            "lastName": "$lastName"
          }
        }
        ''';
      var response = await _http.post('${_url}contact/sync', data: body);
      if (response['contact'] != null) {
        _contactId = response['contact']['id'];
        for (var tag in _tags) {
          await addTagToContact(tag, response['contact']['id']);
        }

        return _contactId;
      }
    }

    _contactId = contact['id'];
    return _contactId;
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

  /// Add a tag into contact. Create if not exist
  Future<void> addTagToContact(String tag, String contactId) async {
    // get all tags
    var response = await _http.get('${_url}tags?limit=100');
    var tagIds = <String, String>{};
    if (response['tags'] != null) {
      List tags = response['tags'];
      tags.forEach((item) {
        tagIds[item['id']] = item['tag'];
      });
    }

    var tagId =
        tagIds.keys.firstWhere((k) => tagIds[k] == tag, orElse: () => null);
    // create tag if not exist
    if (tagId == null) {
      var body = '''
      {
        "tag": {
          "tag": "$tag",
          "tagType": "contact",
          "description": "$tag"
        }
      }
      ''';
      var response = await _http.post('${_url}tags', data: body);
      if (response['tag'] != null) {
        tagId = response['tag']['id'];
      }
    }

    // then add to contact
    var body = '''
      {
        "contactTag": {
          "contact": "$contactId",
          "tag": "$tagId"
        }
      }
      ''';

    await _http.post('${_url}contactTags', data: body);
  }
}

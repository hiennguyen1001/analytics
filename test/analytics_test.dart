import 'package:flutter_test/flutter_test.dart';

import 'package:analytics/analytics.dart';

void main() {
  test('Sending event test', () {
    var config = {
      'activeCampaignAccount': '',
      'activeCampaignKey': '',
      'activeCampaignEventKey': '',
      'activeCampaignEventActid': ''
    };

    var output = ActiveCampaignOutput('user1@test.com', config);
    Analytics.shared.addOutput(output);
    Analytics.shared.sendEvent('test', info: {'data': 'test event'});
    assert(true);
  });
}

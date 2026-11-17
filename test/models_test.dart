import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/models.dart';

void main(){
  test('Post parsing and expiry',(){
    final p=ReachPost.fromJson({
      'id':'id','owner_id':'owner','owner_name':'Test User','title':'Can help with algebra',
      'detail':'Quick call','kind':'offer','category':'Learning','city':'Islamabad',
      'country':'Pakistan','expires_at':'2030-01-01T20:00:00Z',
      'created_at':'2026-11-17T09:00:00Z','circle_name':'','scope':'public'
    });
    expect(p.kind,'offer');expect(p.expired,false);expect(p.city,'Islamabad');
  });
  test('Connection request parsing',(){
    final r=ReachRequest.fromJson({'id':'q','post_id':'p','post_title':'Need help','sender_id':'u',
       'sender_name':'Volunteer','message':'I can help','status':'pending',
       'created_at':'2026-01-01T00:00:00Z'});
    expect(r.status,'pending');expect(r.postTitle,'Need help');
  });
}

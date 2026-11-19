import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_privacy_preferences.dart';

Map<String,dynamic> privateProfile()=> {
  'people_discoverable':false,
  'profile_visibility':'private',
  'allow_calls':false,
  'location_opt_in':false,
  'notify_on':true,
};

Widget screen({
  required Future<void> Function(String,dynamic) save,
  Future<void> Function(bool)? saveNearby,
  VoidCallback? changed,
})=>MaterialApp(home:Scaffold(body:SingleChildScrollView(
  child:ReachPrivacyPreferences(
    profile:privateProfile(),
    onChanged:changed??(){},
    callingEnabled:true,
    pushEnabled:false,
    persistForTest:save,
    persistNearbyForTest:saveNearby,
  ))));

void main(){
  testWidgets('Switch shows pending state until remote save completes',
    (tester)async{
    final pending=Completer<void>();
    final saves=<String>[];
    var acknowledgements=0;
    await tester.pumpWidget(screen(
      save:(key,value){saves.add('$key=$value');return pending.future;},
      changed:()=>acknowledgements++));
    final switches=find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(switches.first).value,false);

    await tester.tap(find.text('Appear in people search'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switches.first).value,true);
    expect(find.text('Saving securely…'),findsOneWidget);
    expect(acknowledgements,0);
    expect(saves,['people_discoverable=true']);

    pending.complete();
    await tester.pump();
    expect(find.text('Saving securely…'),findsNothing);
    expect(acknowledgements,1);
    expect(tester.widget<SwitchListTile>(switches.first).value,true);
  });

  testWidgets('Failed save rolls back and provides explicit retry',
    (tester)async{
    var count=0,acknowledgements=0;
    await tester.pumpWidget(screen(
      save:(key,value)async{
        count++;
        if(count==1)throw StateError('Temporary service problem');
      },changed:()=>acknowledgements++));
    final switches=find.byType(SwitchListTile);
    await tester.tap(find.text('Appear in people search'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switches.first).value,false);
    expect(acknowledgements,0);
    expect(find.textContaining('Temporary service problem'),findsOneWidget);
    expect(find.text('Retry'),findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(count,2);
    expect(acknowledgements,1);
    expect(tester.widget<SwitchListTile>(switches.first).value,true);
    expect(find.text('Retry'),findsNothing);
  });
}

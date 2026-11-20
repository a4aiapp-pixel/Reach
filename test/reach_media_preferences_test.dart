import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reach_network/reach_media_prefs.dart';
import 'package:reach_network/reach_avatar.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  test('Network download defaults protect cellular data and roaming',() async{
    final prefs=await ReachMediaPreferences.load();
    expect(prefs.allows(ReachNetworkKind.mobile,ReachMediaKind.photo),isTrue);
    expect(prefs.allows(ReachNetworkKind.mobile,ReachMediaKind.video),isFalse);
    expect(prefs.allows(ReachNetworkKind.wifi,ReachMediaKind.audio),isTrue);
    expect(prefs.allows(ReachNetworkKind.wifi,ReachMediaKind.document),isFalse);
    for(final kind in ReachMediaKind.values){
      expect(prefs.allows(ReachNetworkKind.roaming,kind),isFalse);
    }
    await prefs.set(ReachNetworkKind.mobile,ReachMediaKind.document,true);
    expect(prefs.allows(ReachNetworkKind.mobile,ReachMediaKind.document),isTrue);
  });

  test('Files are correctly classified by MIME category',(){
    expect(ReachMediaPreferences.classify('image/jpeg'),ReachMediaKind.photo);
    expect(ReachMediaPreferences.classify('audio/ogg'),ReachMediaKind.audio);
    expect(ReachMediaPreferences.classify('video/mp4'),ReachMediaKind.video);
    expect(ReachMediaPreferences.classify('application/pdf'),
      ReachMediaKind.document);
  });

  testWidgets('Photo-free member avatar has clear and cheerful initials',
      (tester)async{
    await tester.pumpWidget(const MaterialApp(
      home:Scaffold(body:Center(
        child:ReachAvatar(name:'Reach Member',size:82,color:'rose')))));
    expect(find.text('RM'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Auto download choices can be changed without extra dialogs',
      (tester)async{
    await tester.pumpWidget(const MaterialApp(home:ReachMediaSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Automatic downloads'),findsOneWidget);
    expect(find.text('Photos'),findsOneWidget);
    expect(find.text('Videos'),findsOneWidget);
    await tester.tap(find.text('Roaming'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile),findsWidgets);
    final switches=tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches.every((v)=>v.value==false),isTrue);
  });
}

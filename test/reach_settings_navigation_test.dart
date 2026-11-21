import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_settings.dart';
import 'package:reach_network/reach_themes.dart';
import 'package:reach_network/main.dart' as reach;

ReachSettingsActions actions()=>ReachSettingsActions(
  viewProfile:(){},editProfile:()async{},
  manageGroups:(){},blockedMembers:(){},
  business:(){},assist:(){},legal:(){},support:(){},
  signOut:(){},deleteAccount:(){},
);

Widget hub({ValueChanged<ThemeMode>? themeChanged})=>MaterialApp(
  theme:reachLookById('aurora').build(Brightness.light),
  home:ReachSettingsHub(
    profile:const {
      'id':'test-uid','display_name':'A Member',
      'username':'member_test','avatar_path':null,
      'avatar_color':'indigo'},
    onProfileChanged:(){},
    themeMode:ThemeMode.system,onTheme:themeChanged??(_){},
    lookId:'aurora',onLook:(_){},
    callingEnabled:true,pushEnabled:false,
    actions:actions(),
  ),
);

void main(){
  testWidgets('Main settings is minimal and groups all preferences',
      (tester)async{
    await tester.pumpWidget(hub());
    expect(find.byType(ReachSettingsHub),findsOneWidget);
    for(final title in const [
      'Profile','Appearance','Chats & media','Calls',
      'Groups','Privacy & security','Help & account',
    ]){expect(find.text(title),findsOneWidget,reason:title);}
    for(final nested in const [
      'Edit profile','Theme gallery','Call quality & network',
      'Media downloads','Allow group invitations','Blocked people',
      'Delete account',
    ]){expect(find.text(nested),findsNothing,reason:'Nested $nested leaked');}
    expect(tester.takeException(),isNull);
  });

  testWidgets('Search routes a control to its one matching section',
      (tester)async{
    await tester.pumpWidget(hub());
    await tester.enterText(find.byType(TextField),'reconnect');
    await tester.pump();
    expect(find.text('Calls'),findsOneWidget);
    expect(find.text('Chats & media'),findsNothing);
    expect(find.text('Appearance'),findsNothing);
  });

  testWidgets('Appearance submenu keeps theme modes and design gallery',
      (tester)async{
    final changed=<ThemeMode>[];
    await tester.pumpWidget(hub(themeChanged:changed.add));
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Display mode'),findsOneWidget);
    expect(find.text('Theme gallery'),findsOneWidget);
    expect(find.text('Delete account'),findsNothing);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(changed,[ThemeMode.light]);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Me page is a short personal landing, not all settings',
      (tester)async{
    await tester.pumpWidget(MaterialApp(
      theme:reachLookById('aurora').build(Brightness.light),
      home:reach.ProfilePage(
        profile:const {
          'id':'testing','display_name':'A Member','username':'member_test',
          'avatar_path':null,'avatar_color':'indigo','city':'Lahore',
          'country':'Pakistan'},
        onChanged:(){},onTheme:(_){},
        themeMode:ThemeMode.system,lookId:'aurora',onLook:(_){},
        onMyReach:(){},
      )));
    expect(find.byKey(const ValueKey('me-profile')),findsOneWidget);
    expect(find.byKey(const ValueKey('me-activity')),findsOneWidget);
    expect(find.byKey(const ValueKey('me-settings')),findsOneWidget);
    expect(find.text('Blocked people'),findsNothing);
    expect(find.text('Delete account'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}

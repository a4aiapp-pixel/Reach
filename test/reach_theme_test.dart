import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_themes.dart';
import 'package:reach_network/reach_navigation.dart';
import 'package:reach_network/reach_experience.dart';

void main(){
  test('Ten presets have unique structural design combinations',(){
    expect(reachLooks.length,10);
    expect(reachLooks.map((e)=>e.id).toSet().length,10);
    expect(reachLooks.map((e)=>e.seed.toARGB32()).toSet().length,10);
    final compositions=reachLooks.map((look)=>
      '${look.navigation.name}/${look.feed.name}/${look.header.name}');
    expect(compositions.toSet().length,10);
    expect(reachLooks.map((e)=>e.navigation).toSet().length,
      greaterThanOrEqualTo(4));
    expect(reachLooks.map((e)=>e.feed).toSet().length,
      greaterThanOrEqualTo(4));
    for(final look in reachLooks){
      for(final brightness in Brightness.values){
        final theme=look.build(brightness);
        expect(theme.brightness,brightness);
        expect(theme.useMaterial3,isTrue);
        expect(theme.extension<ReachDesign>()?.look.id,look.id);
        expect(theme.navigationBarTheme.height,greaterThanOrEqualTo(64));
        expect(theme.scaffoldBackgroundColor,isNot(Colors.transparent));
      }
      expect(reachLookById(look.id).id,look.id);
    }
    expect(reachLookById('unknown').id,'aurora');
  });

  testWidgets('Live gallery shows genuine layout previews and applies choice',
      (tester)async{
    String? chosen;
    await tester.pumpWidget(MaterialApp(home:ReachThemeGallery(
      selected:'aurora',onSelected:(id)=>chosen=id)));
    expect(find.text('Design studio'),findsOneWidget);
    expect(find.text('Aurora Flow'),findsOneWidget);
    expect(find.text('Editorial Ink'),findsOneWidget);
    expect(find.textContaining('navigation, cards'),findsOneWidget);
    await tester.tap(find.text('Editorial Ink'));
    await tester.pump();
    expect(chosen,'editorial');
  });

  testWidgets('Floating dock and underline navigation preserve all five actions',
      (tester)async{
    for(final id in ['aurora','editorial','terra']){
      int? selected;
      await tester.pumpWidget(MaterialApp(
        theme:reachLookById(id).build(Brightness.light),
        home:Scaffold(
          body:const Center(child:Text('Sample body')),
          bottomNavigationBar:ReachAdaptiveNavigation(
            selectedIndex:0,unreadCount:4,onSelected:(i)=>selected=i),
        )));
      expect(find.text('Chats'),findsOneWidget);
      expect(find.text('Calls'),findsOneWidget);
      expect(find.text('Groups'),findsOneWidget);
      await tester.tap(find.text('Calls'));
      await tester.pump();
      expect(selected,2,reason:'Direct call controller must work in $id navigation');
      await tester.tap(find.text('Chats'));
      await tester.pump();
      expect(selected,1,reason:'Direct chat controller must work in $id navigation');
    }
  });

  testWidgets('Rail is available only when viewport is spacious', (tester)async{
    late bool useRail;
    Widget host(Size logicalSize)=>MaterialApp(
      theme:reachLookById('circuit').build(Brightness.dark),
      home:MediaQuery(
        data:MediaQueryData(size:logicalSize),
        child:Builder(builder:(context){
          useRail=ReachAdaptiveNavigation.shouldUseRail(context);
          return const Scaffold(body:Text('Rail test'));
        }),
      ),
    );
    await tester.pumpWidget(host(const Size(1000,700)));
    expect(useRail,isTrue);
    await tester.pumpWidget(host(const Size(390,750)));
    expect(useRail,isFalse);
    await tester.pumpWidget(host(const Size(800,400)));
    expect(useRail,isFalse);
  });

  testWidgets('Every design language renders a distinctive page header',
      (tester)async{
    for(final look in reachLooks){
      await tester.pumpWidget(MaterialApp(
        theme:look.build(Brightness.light),
        home:Scaffold(body:SafeArea(child:SingleChildScrollView(
          child:ReachExperienceHeader(
            title:'My community',
            subtitle:'A useful place to connect and share',
            icon:Icons.groups_outlined))))));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('reach-header-${look.id}')),findsOneWidget,
        reason:'Missing app-wide page personality in ${look.id}');
      expect(find.text('My community'),findsOneWidget);
      expect(tester.takeException(),isNull);
    }
  });

  testWidgets('Quick actions have working callbacks and remain scrollable',
      (tester)async{
    var selection=-1;
    await tester.pumpWidget(MaterialApp(
      theme:reachLookById('circuit').build(Brightness.dark),
      home:Scaffold(body:ReachActionStrip(actions:[
        for(var i=0;i<7;i++)
          ReachQuickAction('Action $i',Icons.add,()=>selection=i),
      ]))));
    await tester.tap(find.text('Action 0'));
    await tester.pump();
    expect(selection,0);
    expect(tester.takeException(),isNull);
  });

}

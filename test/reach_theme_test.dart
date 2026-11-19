import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_themes.dart';
import 'package:reach_network/reach_navigation.dart';

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
      expect(find.text('My Reach'),findsOneWidget);
      expect(find.text('Inbox'),findsOneWidget);
      await tester.tap(find.text('Inbox'));
      await tester.pump();
      expect(selected,2,reason:'Tap must work in $id navigation');
    }
  });

  testWidgets('Rail is available only when viewport is spacious', (tester)async{
    late bool wide;
    await tester.binding.setSurfaceSize(const Size(1000,700));
    await tester.pumpWidget(MaterialApp(
      theme:reachLookById('circuit').build(Brightness.dark),
      home:Builder(builder:(context){
        wide=ReachAdaptiveNavigation.shouldUseRail(context);
        return const Scaffold(body:Text('Rail test'));
      })));
    expect(wide,isTrue);
    await tester.binding.setSurfaceSize(const Size(390,750));
    await tester.pump();
    expect(wide,isFalse);
    await tester.binding.setSurfaceSize(null);
  });
}

import 'package:flutter/material.dart';

/// Reach design systems are structural, not just interchangeable color palettes.
/// The same stable IDs preserve users' existing saved visual preferences.
enum ReachNavigationLayout { standard, dock, underline, rail, tiles }
enum ReachFeedLayout { floating, editorial, compact, accent, bento }
enum ReachHeaderLayout { standard, spotlight, typographic, compact }
enum ReachFilterLayout { inline, sheet }

@immutable
class ReachLook {
  const ReachLook({
    required this.id,required this.name,required this.description,
    required this.seed,required this.canvas,required this.surface,
    required this.darkCanvas,required this.darkSurface,
    required this.radius,required this.navigation,required this.feed,
    required this.header,required this.filters,
    this.elevation=0,this.serif=false,this.mono=false,
    this.condensed=false,this.compact=false,this.centered=false,
    this.preferDark=false,this.outlined=false,this.gutter=18,
    this.accent=const Color(0xFF2CCBC3),
  });
  final String id,name,description;
  final Color seed,canvas,surface,darkCanvas,darkSurface,accent;
  final double radius,elevation,gutter;
  final bool serif,mono,condensed,compact,centered,preferDark,outlined;
  final ReachNavigationLayout navigation;
  final ReachFeedLayout feed;
  final ReachHeaderLayout header;
  final ReachFilterLayout filters;
  String get font => serif?'serif':mono?'monospace':
    condensed?'sans-serif-condensed':'Roboto';

  ThemeData build(Brightness brightness){
    final dark=brightness==Brightness.dark;
    final bg=dark?darkCanvas:canvas;
    final face=dark?darkSurface:surface;
    final base=ColorScheme.fromSeed(seedColor:seed,brightness:brightness);
    final scheme=base.copyWith(surface:face,secondary:accent,
      surfaceContainerLowest:bg,surfaceContainerLow:face);
    final edge=BorderSide(
      color:outlined?scheme.outline.withValues(alpha:.75):
        scheme.outlineVariant.withValues(alpha:.25),
      width:outlined?1.3:.7);
    final corners=BorderRadius.circular(radius);
    final shape=RoundedRectangleBorder(
      borderRadius:corners,side:outlined?edge:BorderSide.none);
    final field=OutlineInputBorder(borderRadius:corners,borderSide:edge);
    final padding=EdgeInsets.symmetric(horizontal:compact?13:18,vertical:compact?9:13);
    final t=ThemeData(useMaterial3:true,brightness:brightness).textTheme
      .apply(fontFamily:font).copyWith(
        displaySmall:TextStyle(fontFamily:font,fontSize:compact?30:38,
          fontWeight:serif?FontWeight.w600:FontWeight.w800,
          letterSpacing:serif?-1.6:-1),
        headlineSmall:TextStyle(fontFamily:font,fontSize:compact?21:26,
          fontWeight:serif?FontWeight.w600:FontWeight.w800,letterSpacing:-.6),
        titleLarge:TextStyle(fontFamily:font,fontSize:compact?19:23,
          fontWeight:FontWeight.w800,letterSpacing:condensed?.25:-.35),
        titleMedium:TextStyle(fontFamily:font,fontSize:compact?15:17,
          fontWeight:FontWeight.w700),
      );
    return ThemeData(
      useMaterial3:true,brightness:brightness,colorScheme:scheme,
      fontFamily:font,textTheme:t,scaffoldBackgroundColor:bg,
      visualDensity:compact?VisualDensity.compact:VisualDensity.standard,
      splashFactory:InkRipple.splashFactory,
      extensions:[ReachDesign(look:this)],
      appBarTheme:AppBarTheme(
        backgroundColor:bg,foregroundColor:scheme.onSurface,
        centerTitle:centered,elevation:elevation,
        scrolledUnderElevation:elevation,
        titleTextStyle:TextStyle(fontFamily:font,fontWeight:FontWeight.w800,
          fontSize:compact?20:23,color:scheme.onSurface)),
      cardTheme:CardThemeData(color:face,elevation:elevation,
        surfaceTintColor:Colors.transparent,shape:shape,
        shadowColor:scheme.shadow.withValues(alpha:.25),
        margin:const EdgeInsets.symmetric(vertical:5)),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:face,contentPadding:padding,
        border:field,enabledBorder:field,
        focusedBorder:OutlineInputBorder(borderRadius:corners,
          borderSide:BorderSide(color:scheme.primary,width:2))),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
        shape:shape,padding:padding,minimumSize:Size(70,compact?43:49),
        textStyle:TextStyle(fontFamily:font,fontWeight:FontWeight.w700))),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
        shape:shape,side:BorderSide(color:scheme.outline),
        padding:padding,minimumSize:Size(70,compact?43:49))),
      textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
        shape:shape,padding:const EdgeInsets.symmetric(horizontal:12,vertical:9))),
      iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(
        shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(radius*.65+4)))),
      navigationBarTheme:NavigationBarThemeData(
        backgroundColor:face,indicatorColor:scheme.primaryContainer,
        elevation:elevation,height:compact?65:77,
        labelBehavior:compact?NavigationDestinationLabelBehavior.onlyShowSelected:
          NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(radius*.72+4))),
      navigationRailTheme:NavigationRailThemeData(
        backgroundColor:face,indicatorColor:scheme.primaryContainer,
        selectedIconTheme:IconThemeData(color:scheme.primary),
        labelType:NavigationRailLabelType.all,
        indicatorShape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(radius*.72+4))),
      floatingActionButtonTheme:FloatingActionButtonThemeData(
        backgroundColor:scheme.primaryContainer,
        foregroundColor:scheme.onPrimaryContainer,
        elevation:elevation+1,shape:shape),
      bottomSheetTheme:BottomSheetThemeData(
        backgroundColor:face,modalBackgroundColor:face,
        showDragHandle:true,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.vertical(
          top:Radius.circular(radius+12)))),
      dialogTheme:DialogThemeData(backgroundColor:face,shape:shape),
      chipTheme:ChipThemeData(
        backgroundColor:face,selectedColor:scheme.primaryContainer,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(radius*.55+4),
          side:outlined?edge:BorderSide.none)),
      dividerTheme:DividerThemeData(color:scheme.outlineVariant,thickness:.7),
      listTileTheme:ListTileThemeData(iconColor:scheme.primary,
        contentPadding:EdgeInsets.symmetric(horizontal:compact?12:18),
        minVerticalPadding:compact?4:8),
      snackBarTheme:SnackBarThemeData(
        behavior:SnackBarBehavior.floating,
        backgroundColor:scheme.inverseSurface,
        contentTextStyle:TextStyle(color:scheme.onInverseSurface,fontFamily:font)),
      textSelectionTheme:TextSelectionThemeData(
        selectionColor:scheme.primary.withValues(alpha:.26),
        cursorColor:scheme.primary),
    );
  }
}

@immutable
class ReachDesign extends ThemeExtension<ReachDesign>{
  const ReachDesign({required this.look});
  final ReachLook look;
  @override
  ReachDesign copyWith({ReachLook? look})=>ReachDesign(look:look??this.look);
  @override
  ReachDesign lerp(covariant ThemeExtension<ReachDesign>? other,double t){
    if(other is! ReachDesign)return this;
    return t<.5?this:other;
  }
  static ReachLook of(BuildContext context)=>
    Theme.of(context).extension<ReachDesign>()?.look??reachLooks.first;
}

/// Ten deliberately different visual systems. No two share the full set
/// of navigation, hero layout and feed presentation.
const reachLooks=<ReachLook>[
  ReachLook(id:'aurora',name:'Aurora Flow',description:'Gradient spotlight · floating dock',
    seed:Color(0xFF5B4FE9),accent:Color(0xFF00B6D1),
    canvas:Color(0xFFF6F7FF),surface:Colors.white,
    darkCanvas:Color(0xFF101124),darkSurface:Color(0xFF21243C),
    radius:24,elevation:1.5,gutter:18,
    navigation:ReachNavigationLayout.dock,feed:ReachFeedLayout.floating,
    header:ReachHeaderLayout.spotlight,filters:ReachFilterLayout.sheet),
  ReachLook(id:'editorial',name:'Editorial Ink',description:'Swiss typography · underline tabs',
    seed:Color(0xFF272729),accent:Color(0xFFAA4E30),
    canvas:Color(0xFFFAF9F5),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF171715),darkSurface:Color(0xFF242421),
    radius:3,serif:true,outlined:true,gutter:23,
    navigation:ReachNavigationLayout.underline,feed:ReachFeedLayout.editorial,
    header:ReachHeaderLayout.typographic,filters:ReachFilterLayout.inline),
  ReachLook(id:'obsidian',name:'Obsidian Pro',description:'Midnight gold · premium cards',
    seed:Color(0xFFD6B278),accent:Color(0xFFDC996A),
    canvas:Color(0xFFF3EEE5),surface:Color(0xFFFFFBF4),
    darkCanvas:Color(0xFF090B0E),darkSurface:Color(0xFF1A2026),
    radius:15,elevation:2.5,preferDark:true,gutter:20,
    navigation:ReachNavigationLayout.dock,feed:ReachFeedLayout.accent,
    header:ReachHeaderLayout.spotlight,filters:ReachFilterLayout.sheet),
  ReachLook(id:'coastal',name:'Coastal Glass',description:'Skyline blue · airy minimalism',
    seed:Color(0xFF027C94),accent:Color(0xFF65B7DF),
    canvas:Color(0xFFEFF9FC),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF0D1A25),darkSurface:Color(0xFF193441),
    radius:30,elevation:1,centered:true,gutter:22,
    navigation:ReachNavigationLayout.standard,feed:ReachFeedLayout.floating,
    header:ReachHeaderLayout.standard,filters:ReachFilterLayout.inline),
  ReachLook(id:'terra',name:'Terra Social',description:'Warm editorial · accent rails',
    seed:Color(0xFFB44B36),accent:Color(0xFFE9A45F),
    canvas:Color(0xFFFFF3E8),surface:Color(0xFFFFFCF7),
    darkCanvas:Color(0xFF201713),darkSurface:Color(0xFF372820),
    radius:14,gutter:19,
    navigation:ReachNavigationLayout.tiles,feed:ReachFeedLayout.accent,
    header:ReachHeaderLayout.typographic,filters:ReachFilterLayout.sheet),
  ReachLook(id:'circuit',name:'Neon Circuit',description:'Signal green · command center',
    seed:Color(0xFF00D5AC),accent:Color(0xFFBEFA44),
    canvas:Color(0xFFEDFFF8),surface:Color(0xFFFBFFFD),
    darkCanvas:Color(0xFF071411),darkSurface:Color(0xFF102620),
    radius:6,compact:true,condensed:true,outlined:true,
    preferDark:true,gutter:13,
    navigation:ReachNavigationLayout.rail,feed:ReachFeedLayout.compact,
    header:ReachHeaderLayout.compact,filters:ReachFilterLayout.sheet),
  ReachLook(id:'alpine',name:'Alpine Focus',description:'Forest calm · distraction-free',
    seed:Color(0xFF376D48),accent:Color(0xFFB2C57B),
    canvas:Color(0xFFF3F7EF),surface:Color(0xFFFEFFFB),
    darkCanvas:Color(0xFF101C15),darkSurface:Color(0xFF223126),
    radius:13,serif:true,gutter:23,
    navigation:ReachNavigationLayout.underline,feed:ReachFeedLayout.compact,
    header:ReachHeaderLayout.typographic,filters:ReachFilterLayout.sheet),
  ReachLook(id:'sakura',name:'Sakura Bento',description:'Pastel bento · expressive motion',
    seed:Color(0xFFD34482),accent:Color(0xFF7F67DC),
    canvas:Color(0xFFFFF4FA),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF23131F),darkSurface:Color(0xFF3A2435),
    radius:30,elevation:1.5,centered:true,gutter:18,
    navigation:ReachNavigationLayout.dock,feed:ReachFeedLayout.bento,
    header:ReachHeaderLayout.spotlight,filters:ReachFilterLayout.sheet),
  ReachLook(id:'blueprint',name:'Blueprint Studio',description:'Precision grid · side navigation',
    seed:Color(0xFF2462D6),accent:Color(0xFF22A9D0),
    canvas:Color(0xFFF0F5FD),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF0B1A35),darkSurface:Color(0xFF142A48),
    radius:4,compact:true,outlined:true,mono:true,gutter:14,
    navigation:ReachNavigationLayout.rail,feed:ReachFeedLayout.editorial,
    header:ReachHeaderLayout.compact,filters:ReachFilterLayout.inline),
  ReachLook(id:'solstice',name:'Solstice Pop',description:'Bold citrus · bento layout',
    seed:Color(0xFFE0781E),accent:Color(0xFFEC4770),
    canvas:Color(0xFFFFF6E9),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF291A0D),darkSurface:Color(0xFF3D2816),
    radius:32,elevation:2,centered:true,gutter:17,
    navigation:ReachNavigationLayout.tiles,feed:ReachFeedLayout.bento,
    header:ReachHeaderLayout.spotlight,filters:ReachFilterLayout.inline),
];

ReachLook reachLookById(String id){
  for(final look in reachLooks){
    if(look.id==id)return look;
  }
  return reachLooks.first;
}

/// In-gallery previews show real layout differences: header, post surface and
/// navigation rather than the old same-sized colored rectangles.
class ReachThemeGallery extends StatefulWidget {
  const ReachThemeGallery({super.key,required this.selected,required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override State<ReachThemeGallery> createState()=>_ReachThemeGalleryState();
}
class _ReachThemeGalleryState extends State<ReachThemeGallery>{
  late String current;
  @override void initState(){super.initState();current=widget.selected;}
  @override void didUpdateWidget(covariant ReachThemeGallery oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.selected!=oldWidget.selected)current=widget.selected;
  }

  Widget _miniPreview(ReachLook look){
    final dark=look.preferDark;
    final surface=dark?look.darkSurface:look.surface;
    final bg=dark?look.darkCanvas:look.canvas;
    final foreground=dark?Colors.white:const Color(0xFF1A2330);
    final round=BorderRadius.circular(look.radius.clamp(4.0,24.0).toDouble());
    final accent=look.seed;
    final headerGlow=look.header==ReachHeaderLayout.spotlight;
    final compact=look.header==ReachHeaderLayout.compact;
    Widget bar(double width,{double height=5,Color? color})=>Container(
      width:width,height:height,decoration:BoxDecoration(
        color:color??foreground.withValues(alpha:.45),
        borderRadius:BorderRadius.circular(3)));
    return Container(
      decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(12)),
      padding:const EdgeInsets.all(9),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(
          width:double.infinity,
          padding:EdgeInsets.all(compact?5:9),
          decoration:BoxDecoration(
            gradient:headerGlow?LinearGradient(colors:[accent,look.accent]):null,
            color:headerGlow?null:surface,
            borderRadius:round),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Icon(compact?Icons.grid_view_rounded:Icons.hub_rounded,
                color:headerGlow?Colors.white:accent,size:compact?13:18),
              const Spacer(),
              Icon(Icons.search,size:12,color:headerGlow?Colors.white:foreground),
              const SizedBox(width:6),
              Icon(Icons.more_horiz,size:12,color:headerGlow?Colors.white:foreground),
            ]),
            const SizedBox(height:5),
            bar(look.header==ReachHeaderLayout.typographic?96:66,
              height:look.header==ReachHeaderLayout.typographic?8:6,
              color:headerGlow?Colors.white:foreground),
            if(!compact)...[const SizedBox(height:5),
              bar(80,height:4,color:headerGlow?
                Colors.white.withValues(alpha:.7):foreground.withValues(alpha:.25))]
          ]),
        ),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:Container(height:15,decoration:BoxDecoration(
            color:surface,border:Border.all(color:accent.withValues(alpha:.35)),
            borderRadius:round))),
          const SizedBox(width:5),
          Container(width:28,height:15,decoration:BoxDecoration(
            color:accent.withValues(alpha:.3),borderRadius:round))
        ]),
        const SizedBox(height:8),
        Expanded(child:Container(
          width:double.infinity,padding:const EdgeInsets.all(8),
          decoration:BoxDecoration(color:surface,
            borderRadius:look.feed==ReachFeedLayout.editorial?
              BorderRadius.circular(2):round,
            border:look.outlined?Border.all(color:accent.withValues(alpha:.7)):null),
          child:Row(children:[
            if(look.feed==ReachFeedLayout.accent)
              Container(width:4,margin:const EdgeInsets.only(right:8),color:accent),
            if(look.feed==ReachFeedLayout.bento)
              Container(width:30,margin:const EdgeInsets.only(right:8),
                decoration:BoxDecoration(color:look.accent.withValues(alpha:.35),
                  borderRadius:round),
                child:Icon(Icons.favorite_outline,color:accent,size:15)),
            Expanded(child:Column(
              mainAxisAlignment:MainAxisAlignment.center,
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              bar(look.feed==ReachFeedLayout.compact?54:72,height:7,color:foreground),
              const SizedBox(height:6),
              bar(91,height:4,color:foreground.withValues(alpha:.25)),
              const SizedBox(height:4),
              bar(65,height:4,color:foreground.withValues(alpha:.18)),
            ])),
          ]),
        )),
        const SizedBox(height:7),
        Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
          for(var i=0;i<5;i++)
            Container(width:i==0&&look.navigation==ReachNavigationLayout.dock?24:13,
              height:16,decoration:BoxDecoration(
                color:i==0?accent:surface,
                borderRadius:look.navigation==ReachNavigationLayout.tiles?
                  BorderRadius.circular(3):BorderRadius.circular(11),
                border:look.navigation==ReachNavigationLayout.underline&&i==0?
                  Border.all(color:accent.withValues(alpha:.45),width:1):null),
              child:Icon([Icons.explore,Icons.bolt,Icons.chat,Icons.groups,Icons.person][i],
                size:9,color:i==0?Colors.white:foreground.withValues(alpha:.55))),
        ]),
      ]));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Design studio')),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(17,7,17,12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Choose a different experience',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:5),
          Text('10 layouts · different navigation, cards, headers and density. '
            'Tap a preview to apply it instantly.',
            style:Theme.of(context).textTheme.bodySmall),
        ])),
      Expanded(child:GridView.builder(
        padding:const EdgeInsets.fromLTRB(13,2,13,22),
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent:250,childAspectRatio:.69,
          mainAxisSpacing:12,crossAxisSpacing:12),
        itemCount:reachLooks.length,
        itemBuilder:(context,index){
          final look=reachLooks[index];
          final selected=look.id==current;
          return Semantics(button:true,selected:selected,
            label:'Select ${look.name} theme',
            child:Material(color:Colors.transparent,
              child:InkWell(
                onTap:(){
                  setState(()=>current=look.id);
                  widget.onSelected(look.id);
                },
                borderRadius:BorderRadius.circular(17),
                child:AnimatedContainer(
                  duration:const Duration(milliseconds:180),
                  padding:const EdgeInsets.all(7),
                  decoration:BoxDecoration(
                    color:Theme.of(context).colorScheme.surface,
                    borderRadius:BorderRadius.circular(17),
                    border:Border.all(
                      color:selected?Theme.of(context).colorScheme.primary:
                        Theme.of(context).colorScheme.outlineVariant,
                      width:selected?2.3:1)),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Expanded(child:_miniPreview(look)),
                    const SizedBox(height:7),
                    Row(children:[
                      Expanded(child:Text(look.name,maxLines:1,
                        overflow:TextOverflow.ellipsis,
                        style:Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight:FontWeight.w800))),
                      if(selected)Icon(Icons.check_circle,
                        size:17,color:Theme.of(context).colorScheme.primary),
                    ]),
                    Text(look.description,maxLines:1,overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.labelSmall),
                  ]),
                ),
              )));
        },
      )),
      Padding(padding:const EdgeInsets.fromLTRB(16,4,16,12),
        child:Text('Previews illustrate style only, not actual community activity.',
          style:Theme.of(context).textTheme.labelSmall,
          textAlign:TextAlign.center)),
    ])));
}

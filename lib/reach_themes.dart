import 'package:flutter/material.dart';

/// Ten design systems: each changes palettes, density, typography, corners,
/// buttons, fields, sheets, cards, navigation, and app bars app-wide.
/// All palettes retain Material 3 semantic contrast and system text scaling.
class ReachLook {
  const ReachLook({
    required this.id, required this.name, required this.description,
    required this.seed, required this.canvas, required this.surface,
    required this.darkCanvas, required this.darkSurface,
    required this.radius, this.elevation=0, this.serif=false,
    this.condensed=false, this.compact=false, this.centered=false,
    this.preferDark=false, this.outlined=false,
  });
  final String id, name, description;
  final Color seed, canvas, surface, darkCanvas, darkSurface;
  final double radius, elevation;
  final bool serif, condensed, compact, centered, preferDark, outlined;

  ThemeData build(Brightness brightness) {
    final dark=brightness==Brightness.dark;
    final base=ColorScheme.fromSeed(seedColor:seed,brightness:brightness);
    final surfaceColor=dark?darkSurface:surface;
    final bgColor=dark?darkCanvas:canvas;
    final scheme=base.copyWith(surface:surfaceColor);
    final edge=BorderSide(color:outlined?scheme.outline.withValues(alpha:.7):
      scheme.outlineVariant.withValues(alpha:.25),
      width:outlined?1.4:0.6);
    final r=BorderRadius.circular(radius);
    final shape=RoundedRectangleBorder(borderRadius:r,
      side:outlined?edge:BorderSide.none);
    final field=OutlineInputBorder(borderRadius:r,borderSide:edge);
    final font=serif?'serif':(condensed?'sans-serif-condensed':'Roboto');
    final dense=compact?const EdgeInsets.symmetric(horizontal:14,vertical:9):
      const EdgeInsets.symmetric(horizontal:19,vertical:13);
    final typography=ThemeData(brightness:brightness,useMaterial3:true).textTheme
      .apply(fontFamily:font).copyWith(
      displaySmall:TextStyle(fontFamily:font,fontSize:compact?30:36,
        fontWeight:serif?FontWeight.w600:FontWeight.w800,letterSpacing:serif?-1.3:-.8),
      headlineSmall:TextStyle(fontFamily:font,fontSize:compact?22:26,
        fontWeight:FontWeight.w700,letterSpacing:-.5),
      titleLarge:TextStyle(fontFamily:font,fontWeight:FontWeight.w700,
        letterSpacing:condensed ? 0.3 : -0.3),
    );
    return ThemeData(
      useMaterial3:true,
      brightness:brightness,
      colorScheme:scheme,
      fontFamily:font,
      textTheme:typography,
      visualDensity:compact?VisualDensity.compact:VisualDensity.standard,
      scaffoldBackgroundColor:bgColor,
      splashFactory:InkRipple.splashFactory,
      appBarTheme:AppBarTheme(
        backgroundColor:bgColor,
        foregroundColor:scheme.onSurface,
        elevation:elevation,
        centerTitle:centered,
        scrolledUnderElevation:elevation,
        titleTextStyle:TextStyle(fontFamily:font,fontWeight:FontWeight.w800,
          fontSize:compact?19:22,color:scheme.onSurface),
      ),
      cardTheme:CardThemeData(color:surfaceColor,elevation:elevation,
        surfaceTintColor:Colors.transparent,shape:shape,
        shadowColor:scheme.shadow.withValues(alpha:.24),
        margin:const EdgeInsets.symmetric(vertical:5)),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:surfaceColor,
        contentPadding:dense,
        border:field,
        enabledBorder:field,
        focusedBorder:OutlineInputBorder(borderRadius:r,
          borderSide:BorderSide(color:scheme.primary,width:2)),
      ),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
        shape:shape,padding:dense,
        minimumSize:Size(66,compact?42:48),
        textStyle:TextStyle(fontFamily:font,fontWeight:FontWeight.w700))),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(
        shape:shape,padding:dense,
        side:BorderSide(color:scheme.outline),
        minimumSize:Size(66,compact?42:48))),
      textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(
        shape:shape,padding:const EdgeInsets.symmetric(horizontal:12,vertical:9))),
      iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(radius*.68)))),
      navigationBarTheme:NavigationBarThemeData(
        backgroundColor:surfaceColor,
        indicatorColor:scheme.primaryContainer,
        elevation:elevation,
        height:compact?64:78,
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape:RoundedRectangleBorder(borderRadius:
          BorderRadius.circular(radius*.8))),
      floatingActionButtonTheme:FloatingActionButtonThemeData(
        backgroundColor:scheme.primaryContainer,
        foregroundColor:scheme.onPrimaryContainer,
        elevation:elevation+1,
        shape:shape),
      bottomSheetTheme:BottomSheetThemeData(backgroundColor:surfaceColor,
        modalBackgroundColor:surfaceColor,showDragHandle:true,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.vertical(
          top:Radius.circular(radius*1.4)))),
      dialogTheme:DialogThemeData(backgroundColor:surfaceColor,shape:shape),
      chipTheme:ChipThemeData(backgroundColor:surfaceColor,
        selectedColor:scheme.primaryContainer,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(radius*.65),
          side:outlined?edge:BorderSide.none)),
      dividerTheme:DividerThemeData(color:scheme.outlineVariant,thickness:.7),
      listTileTheme:ListTileThemeData(iconColor:scheme.primary,
        contentPadding:EdgeInsets.symmetric(horizontal:compact?12:18)),
      snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,
        backgroundColor:scheme.inverseSurface,contentTextStyle:TextStyle(
          color:scheme.onInverseSurface,fontFamily:font)),
    );
  }
}

const reachLooks=<ReachLook>[
  ReachLook(id:'aurora',name:'Aurora',description:'Soft modern • floating',
    seed:Color(0xFF635CF4),canvas:Color(0xFFF7F8FF),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF121325),darkSurface:Color(0xFF22243B),radius:24,elevation:1),
  ReachLook(id:'editorial',name:'Editorial',description:'Monochrome • typography',
    seed:Color(0xFF303030),canvas:Color(0xFFFAF9F5),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF191918),darkSurface:Color(0xFF262624),radius:3,
    serif:true,outlined:true),
  ReachLook(id:'obsidian',name:'Obsidian',description:'Black metal • champagne',
    seed:Color(0xFFD5AA65),canvas:Color(0xFFF0EAE1),surface:Color(0xFFFCF7EF),
    darkCanvas:Color(0xFF080A0D),darkSurface:Color(0xFF1D2025),radius:14,
    preferDark:true,elevation:2),
  ReachLook(id:'coastal',name:'Coastal',description:'Ocean blue • spacious',
    seed:Color(0xFF087D95),canvas:Color(0xFFF0FAFC),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF0D1B25),darkSurface:Color(0xFF162D3B),radius:30,
    elevation:1,centered:true),
  ReachLook(id:'terra',name:'Terra',description:'Terracotta • warm surfaces',
    seed:Color(0xFFBA573C),canvas:Color(0xFFFFF6EC),surface:Color(0xFFFFFBF5),
    darkCanvas:Color(0xFF241A17),darkSurface:Color(0xFF382620),radius:17),
  ReachLook(id:'circuit',name:'Circuit',description:'Neon signal • condensed',
    seed:Color(0xFF00BC9A),canvas:Color(0xFFEFFFFB),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF071612),darkSurface:Color(0xFF102A23),radius:5,
    preferDark:true,compact:true,outlined:true,condensed:true),
  ReachLook(id:'alpine',name:'Alpine',description:'Botanical • understated',
    seed:Color(0xFF467B51),canvas:Color(0xFFF1F7EF),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF101B15),darkSurface:Color(0xFF1C2E24),radius:13,
    elevation:.5),
  ReachLook(id:'sakura',name:'Sakura',description:'Rose tones • delicate',
    seed:Color(0xFFC45188),canvas:Color(0xFFFFF5FA),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF251620),darkSurface:Color(0xFF3A2532),radius:29,
    centered:true),
  ReachLook(id:'blueprint',name:'Blueprint',description:'Technical • crisp grid',
    seed:Color(0xFF175BD7),canvas:Color(0xFFF2F5FB),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF081A35),darkSurface:Color(0xFF152B49),radius:6,
    compact:true,outlined:true,condensed:true),
  ReachLook(id:'solstice',name:'Solstice',description:'Saffron • bold friendly',
    seed:Color(0xFFCB7500),canvas:Color(0xFFFFFAEB),surface:Color(0xFFFFFFFF),
    darkCanvas:Color(0xFF291D0C),darkSurface:Color(0xFF3E2C15),radius:38,
    elevation:2,centered:true),
];

ReachLook reachLookById(String id) {
  for(final look in reachLooks) {
    if(look.id==id)return look;
  }
  return reachLooks.first;
}

class ReachThemeGallery extends StatefulWidget {
  const ReachThemeGallery({super.key,required this.selected,required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override State<ReachThemeGallery> createState()=>_ReachThemeGalleryState();
}
class _ReachThemeGalleryState extends State<ReachThemeGallery> {
  late String current;
  @override void initState(){super.initState();current=widget.selected;}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Design studio')),
    body:SafeArea(child:GridView.builder(
      padding:const EdgeInsets.all(16),
      gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent:230,childAspectRatio:.84,mainAxisSpacing:14,crossAxisSpacing:14),
      itemCount:reachLooks.length,
      itemBuilder:(context,index){
        final look=reachLooks[index];
        final scheme=ColorScheme.fromSeed(seedColor:look.seed,
          brightness:look.preferDark?Brightness.dark:Brightness.light);
        final background=look.preferDark?look.darkCanvas:look.canvas;
        final face=look.preferDark?look.darkSurface:look.surface;
        final radius=BorderRadius.circular(look.radius);
        return Semantics(button:true,selected:look.id==current,
          label:'Select ${look.name} theme',child:InkWell(
          onTap:(){setState(()=>current=look.id);widget.onSelected(look.id);},
          borderRadius:radius,
          child:Container(
            decoration:BoxDecoration(color:background,borderRadius:radius,
              border:Border.all(color:look.id==current?look.seed:scheme.outlineVariant,
                width:look.id==current?3:1)),
            padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                CircleAvatar(radius:10,backgroundColor:look.seed),
                const Spacer(),
                if(look.id==current)Icon(Icons.check_circle,color:look.seed,size:21),
              ]),
              const SizedBox(height:13),
              Container(height:36,alignment:Alignment.centerLeft,
                padding:const EdgeInsets.symmetric(horizontal:10),
                decoration:BoxDecoration(color:face,borderRadius:radius),
                child:Row(children:[
                  Icon(Icons.favorite_outline,color:look.seed,size:17),
                  const SizedBox(width:8),
                  Expanded(child:Container(height:6,decoration:BoxDecoration(
                    color:scheme.onSurface.withValues(alpha:.27),
                    borderRadius:BorderRadius.circular(3)))),
                ])),
              const SizedBox(height:9),
              Row(children:[
                Expanded(child:Container(height:35,
                  decoration:BoxDecoration(color:look.seed,borderRadius:radius))),
                const SizedBox(width:6),
                Expanded(child:Container(height:35,
                  decoration:BoxDecoration(color:face,borderRadius:radius,
                    border:Border.all(color:look.seed)))),
              ]),
              const Spacer(),
              Text(look.name,style:TextStyle(color:scheme.onSurface,
                fontFamily:look.serif?'serif':'Roboto',
                fontSize:17,fontWeight:FontWeight.w800)),
              Text(look.description,maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:scheme.onSurface.withValues(alpha:.7),fontSize:11)),
            ]),
          )));
      },
    )));
}

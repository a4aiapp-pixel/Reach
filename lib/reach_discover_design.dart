import 'package:flutter/material.dart';
import 'reach_themes.dart';

/// A theme's Discover header is a genuine layout, not the same logo row
/// with a different background. All modes retain the same functional actions.
class ReachDiscoverHero extends StatelessWidget {
  const ReachDiscoverHero({super.key,
    required this.onPeople,required this.onAssist,required this.onRefresh});
  final VoidCallback onPeople,onAssist,onRefresh;

  Widget _mark(double size,{Color? color}){
    return ClipRRect(
      borderRadius:BorderRadius.circular(size*.24),
      child:Image.asset('assets/branding/reach_selected_icon.webp',
        width:size,height:size,fit:BoxFit.cover,
        semanticLabel:'Reach app mark'));
  }
  Widget _actions(Color foreground){
    return Row(mainAxisSize:MainAxisSize.min,children:[
      IconButton(
        tooltip:'Find people',onPressed:onPeople,
        visualDensity:VisualDensity.compact,
        icon:Icon(Icons.people_alt_outlined,color:foreground)),
      IconButton(
        tooltip:'Reach Assist',onPressed:onAssist,
        visualDensity:VisualDensity.compact,
        icon:Icon(Icons.auto_awesome,color:foreground)),
      IconButton(
        tooltip:'Refresh',onPressed:onRefresh,
        visualDensity:VisualDensity.compact,
        icon:Icon(Icons.refresh_rounded,color:foreground)),
    ]);
  }

  @override Widget build(BuildContext context){
    final look=ReachDesign.of(context);
    final theme=Theme.of(context),scheme=theme.colorScheme;
    final text=theme.textTheme;
    final isCompact=look.header==ReachHeaderLayout.compact;
    if(look.header==ReachHeaderLayout.spotlight){
      return Container(
        width:double.infinity,
        padding:EdgeInsets.fromLTRB(look.compact?11:16,12,8,14),
        decoration:BoxDecoration(
          gradient:LinearGradient(
            begin:Alignment.topLeft,end:Alignment.bottomRight,
            colors:theme.brightness==Brightness.dark
              ?[scheme.primary.withValues(alpha:.65),
                look.accent.withValues(alpha:.38)]
              :[look.seed,look.accent]),
          borderRadius:BorderRadius.circular(look.radius.clamp(13.0,30.0).toDouble())),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            _mark(look.compact?31:35),
            const SizedBox(width:10),
            Expanded(child:Text('REACH / COMMUNITY',
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,
                letterSpacing:1.2,fontSize:11))),
            _actions(Colors.white),
          ]),
          const SizedBox(height:8),
          Text('Make a connection.',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:text.headlineSmall?.copyWith(
              color:Colors.white,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text('Find help, share skills, discover your community.',
            maxLines:2,overflow:TextOverflow.ellipsis,
            style:text.bodySmall?.copyWith(
              color:Colors.white.withValues(alpha:.9))),
        ]));
    }
    if(look.header==ReachHeaderLayout.typographic){
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          _mark(30),const SizedBox(width:9),
          Expanded(child:Text('REACH',
            style:text.labelLarge?.copyWith(
              fontWeight:FontWeight.w900,letterSpacing:2.1))),
          _actions(scheme.onSurface),
        ]),
        const SizedBox(height:6),
        Text('People. Purpose. Progress.',
          maxLines:2,
          style:text.headlineSmall?.copyWith(
            fontFamily:look.font,fontWeight:FontWeight.w800,
            color:scheme.onSurface)),
        const SizedBox(height:4),
        Container(height:look.outlined?2:1,width:double.infinity,
          color:look.outlined?scheme.onSurface:scheme.outlineVariant),
      ]);
    }
    if(isCompact){
      return Row(children:[
        _mark(32),const SizedBox(width:9),
        Expanded(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text('Reach',style:text.titleLarge?.copyWith(
              fontWeight:FontWeight.w900)),
            Text('Find your community',maxLines:1,overflow:TextOverflow.ellipsis,
              style:text.labelSmall),
          ])),
        _actions(scheme.onSurface),
      ]);
    }
    return Row(children:[
      _mark(42),const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text('Reach',style:text.titleLarge?.copyWith(
            fontWeight:FontWeight.w900)),
          Text('Good things happen when we connect',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:text.bodySmall),
        ])),
      _actions(scheme.onSurface),
    ]);
  }
}

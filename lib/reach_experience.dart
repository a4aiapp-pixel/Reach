import 'package:flutter/material.dart';
import 'reach_themes.dart';

/// A reusable page masthead. Ten design languages alter actual composition,
/// not only colors, to keep Explore, Chats, Calls, Groups and Me coherent.
class ReachExperienceHeader extends StatelessWidget {
  const ReachExperienceHeader({super.key,required this.title,
    required this.subtitle,required this.icon,this.actions});
  final String title,subtitle;
  final IconData icon;
  final Widget? actions;

  @override Widget build(BuildContext context){
    final theme=Theme.of(context),look=ReachDesign.of(context);
    final scheme=theme.colorScheme,dark=theme.brightness==Brightness.dark;
    final isInk=look.id=='editorial',isTech=look.id=='circuit'||look.id=='blueprint';
    final isFlat=look.id=='alpine',isSplit=look.id=='sakura'||look.id=='solstice';
    final isWarm=look.id=='terra',isPremium=look.id=='obsidian';
    final isGradient=look.id=='aurora'||isSplit||isPremium;
    final lightText=isGradient&&(!dark||isPremium);
    final foreground=lightText?Colors.white:scheme.onSurface;
    final accent=look.seed;
    final radius=BorderRadius.circular(look.radius.clamp(3.0,29.0).toDouble());
    final gap=look.compact?8.0:13.0;
    final shade=look.id=='obsidian'?const Color(0xFF151920):
      look.id=='sakura'?const Color(0xFFD5438A):look.id=='solstice'
        ?const Color(0xFFDF6515):accent;
    final panel=Container(
      width:double.infinity,
      padding:EdgeInsets.symmetric(
        vertical:look.compact?12:18,horizontal:look.compact?12:18),
      decoration:BoxDecoration(
        color:isFlat||isInk?Colors.transparent:
          isGradient?null:scheme.surface,
        gradient:isGradient?LinearGradient(
          begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[shade,look.accent]):null,
        borderRadius:isFlat||isInk?BorderRadius.zero:radius,
        border:isTech||isWarm?Border.all(color:accent.withValues(alpha:.58),
          width:isTech?1.5:1):null,
        boxShadow:isGradient&&!dark?[
          BoxShadow(color:shade.withValues(alpha:.15),
            blurRadius:17,offset:const Offset(0,5))
        ]:null),
      child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        if(isInk)Container(width:3,height:57,color:accent),
        if(isInk)SizedBox(width:gap),
        if(!isInk)Container(
          height:isSplit?57:look.compact?43:53,
          width:isSplit?57:look.compact?43:53,
          alignment:Alignment.center,
          decoration:BoxDecoration(
            color:lightText?Colors.white.withValues(alpha:.19):
              accent.withValues(alpha:isFlat ? .12 : .10),
            borderRadius:BorderRadius.circular(
              isTech?5:isSplit?13:look.radius.clamp(7.0,23.0).toDouble()),
            border:isTech?Border.all(color:foreground.withValues(alpha:.25)):null,
          ),
          child:Icon(icon,size:isSplit?30:25,color:foreground)),
        if(!isInk)SizedBox(width:gap),
        Expanded(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(isTech)Text(look.id=='circuit'?'// REACH CONNECT':
            'REACH / WORKSPACE',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:foreground.withValues(alpha:.73),
              fontFamily:look.font,letterSpacing:1.7,fontSize:10)),
          Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
            style:theme.textTheme.headlineSmall?.copyWith(
              fontFamily:look.font,
              color:foreground,fontWeight:isInk?FontWeight.w600:FontWeight.w900,
              letterSpacing:isInk?-1.3:look.compact?-.6:-.9)),
          const SizedBox(height:4),
          Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
            style:theme.textTheme.bodySmall?.copyWith(
              color:foreground.withValues(alpha:.85))),
        ])),
        if(actions!=null)...[SizedBox(width:gap),
          IconTheme(data:IconThemeData(color:foreground),child:actions!)],
      ]),
    );
    return Column(key:ValueKey('reach-header-${look.id}'),
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(isTech)Padding(padding:const EdgeInsets.only(bottom:4),
        child:Row(children:[
          Expanded(child:Container(height:2,color:accent)),
          const SizedBox(width:7),
          Container(width:24,height:2,color:look.accent),
        ])),
      panel,
      if(isInk||isFlat)Container(
        margin:const EdgeInsets.only(top:9),height:isInk?2:1,
        color:isInk?scheme.onSurface:scheme.outlineVariant),
    ]);
  }
}

/// Compact, responsive application actions; avoids multi-row giant controls
/// on landscape phones. Actions are real navigation, never inert decoration.
class ReachActionStrip extends StatelessWidget {
  const ReachActionStrip({super.key,required this.actions});
  final List<ReachQuickAction> actions;

  @override Widget build(BuildContext context){
    final look=ReachDesign.of(context),scheme=Theme.of(context).colorScheme;
    return SizedBox(height:look.compact?64:78,child:ListView.separated(
      scrollDirection:Axis.horizontal,
      padding:EdgeInsets.zero,itemCount:actions.length,
      separatorBuilder:(_,__)=>const SizedBox(width:9),
      itemBuilder:(ctx,i){
        final a=actions[i];
        return Semantics(button:true,label:a.label,child:Material(
          color:scheme.surface,
          shape:RoundedRectangleBorder(
            borderRadius:BorderRadius.circular(
              look.navigation==ReachNavigationLayout.underline?4:look.radius),
            side:BorderSide(color:scheme.outlineVariant.withValues(alpha:.43))),
          clipBehavior:Clip.antiAlias,
          child:InkWell(onTap:a.onTap,
            child:Padding(padding:EdgeInsets.symmetric(
              horizontal:look.compact?12:16,vertical:9),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Icon(a.icon,color:scheme.primary,size:look.compact?20:23),
                const SizedBox(height:5),
                Text(a.label,style:Theme.of(ctx).textTheme.labelSmall
                  ?.copyWith(fontWeight:FontWeight.w800)),
              ]))),
        ));
      }));
  }
}
class ReachQuickAction {
  const ReachQuickAction(this.label,this.icon,this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

import 'package:flutter/material.dart';
import 'reach_themes.dart';

/// Reach's navigation is deliberately part of the chosen design system.
/// All five destinations remain accessible at every supported screen size.
class ReachAdaptiveNavigation extends StatelessWidget {
  const ReachAdaptiveNavigation({super.key,required this.selectedIndex,
    required this.onSelected,this.unreadCount=0});
  final int selectedIndex,unreadCount;
  final ValueChanged<int> onSelected;

  static const labels=<String>['Explore','Chats','Calls','Groups','Me'];
  static const icons=<IconData>[
    Icons.explore_outlined,Icons.chat_bubble_outline,Icons.call_outlined,
    Icons.groups_outlined,Icons.person_outline,
  ];
  static const activeIcons=<IconData>[
    Icons.explore,Icons.chat_bubble,Icons.call,Icons.groups,Icons.person,
  ];

  static bool shouldUseRail(BuildContext context){
    final look=ReachDesign.of(context);
    final size=MediaQuery.sizeOf(context);
    return look.navigation==ReachNavigationLayout.rail &&
      size.width>=760 && size.height>=500;
  }

  Widget _icon(int i,bool selected,{double size=23}){
    final icon=Icon(selected?activeIcons[i]:icons[i],size:size);
    if(i!=1||unreadCount==0)return icon;
    return Badge(
      label:Text(unreadCount>49?'49+':'$unreadCount'),
      child:icon,
    );
  }

  @override Widget build(BuildContext context){
    final look=ReachDesign.of(context);
    if(look.navigation==ReachNavigationLayout.standard){
      return NavigationBar(
        selectedIndex:selectedIndex,onDestinationSelected:onSelected,
        destinations:[
          for(var i=0;i<labels.length;i++)
            NavigationDestination(
              icon:_icon(i,false),selectedIcon:_icon(i,true),
              label:labels[i],
            ),
        ]);
    }
    final scheme=Theme.of(context).colorScheme;
    final bottomDock=look.navigation==ReachNavigationLayout.dock;
    final underline=look.navigation==ReachNavigationLayout.underline;
    final tiles=look.navigation==ReachNavigationLayout.tiles ||
      look.navigation==ReachNavigationLayout.rail;
    final dark=Theme.of(context).brightness==Brightness.dark;
    final background=bottomDock?scheme.surface:
      underline?Theme.of(context).scaffoldBackgroundColor:scheme.surface;
    final radius=bottomDock?30.0:underline?0.0:tiles?10.0:16.0;
    final height=look.compact?61.0:69.0;

    return SafeArea(top:false,child:Padding(
      padding:EdgeInsets.fromLTRB(bottomDock?13:0,3,bottomDock?13:0,bottomDock?8:0),
      child:Material(
        color:background,
        elevation:bottomDock?7:0,
        shadowColor:scheme.shadow.withValues(alpha:dark ? .65 : .25),
        shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(radius),
          side:bottomDock?BorderSide(
            color:scheme.outlineVariant.withValues(alpha:.35)):BorderSide.none),
        clipBehavior:Clip.antiAlias,
        child:SizedBox(height:height,child:Row(children:[
          for(var i=0;i<labels.length;i++)
            Expanded(child:Semantics(button:true,selected:i==selectedIndex,
              label:labels[i],child:InkWell(
                onTap:()=>onSelected(i),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  if(underline)
                    AnimatedContainer(duration:const Duration(milliseconds:170),
                      height:3,width:20,
                      margin:const EdgeInsets.only(bottom:6),
                      decoration:BoxDecoration(
                        color:i==selectedIndex?scheme.primary:Colors.transparent,
                        borderRadius:BorderRadius.circular(2))),
                  AnimatedContainer(
                    duration:const Duration(milliseconds:170),
                    height:bottomDock?34:tiles?30:27,
                    width:bottomDock?45:tiles?38:36,
                    alignment:Alignment.center,
                    decoration:BoxDecoration(
                      color:i==selectedIndex?
                        (bottomDock?scheme.primary:scheme.primaryContainer):
                        Colors.transparent,
                      borderRadius:BorderRadius.circular(
                        bottomDock?19:tiles?look.radius.clamp(4.0,13.0).toDouble():9)),
                    child:IconTheme(
                      data:IconThemeData(color:i==selectedIndex?
                        (bottomDock?scheme.onPrimary:scheme.onPrimaryContainer):
                        scheme.onSurfaceVariant),
                      child:_icon(i,i==selectedIndex,size:look.compact?19:22)),
                  ),
                  const SizedBox(height:3),
                  Text(labels[i],maxLines:1,overflow:TextOverflow.ellipsis,
                    textAlign:TextAlign.center,
                    style:TextStyle(
                      fontFamily:look.font,fontSize:look.compact?9.5:10.5,
                      letterSpacing:look.mono?-.45:0,
                      color:i==selectedIndex?scheme.primary:scheme.onSurfaceVariant,
                      fontWeight:i==selectedIndex?FontWeight.w800:FontWeight.w500)),
                ]),
              ))),
        ]))),
      ),
    );
  }
}

class ReachAdaptiveRail extends StatelessWidget {
  const ReachAdaptiveRail({super.key,required this.selectedIndex,
    required this.onSelected,this.unreadCount=0});
  final int selectedIndex,unreadCount;
  final ValueChanged<int> onSelected;

  @override Widget build(BuildContext context){
    final theme=Theme.of(context);
    final scheme=theme.colorScheme;
    return NavigationRail(
      selectedIndex:selectedIndex,
      onDestinationSelected:onSelected,
      extended:false,
      minWidth:80,
      backgroundColor:scheme.surface,
      useIndicator:true,
      groupAlignment:-.82,
      leading:Padding(
        padding:const EdgeInsets.symmetric(vertical:14),
        child:Icon(Icons.hub_rounded,color:scheme.primary,size:29)),
      labelType:NavigationRailLabelType.all,
      destinations:[
        for(var i=0;i<ReachAdaptiveNavigation.labels.length;i++)
          NavigationRailDestination(
            icon:i==1&&unreadCount>0
              ?Badge(label:Text(unreadCount>49?'49+':'$unreadCount'),
                child:Icon(ReachAdaptiveNavigation.icons[i]))
              :Icon(ReachAdaptiveNavigation.icons[i]),
            selectedIcon:i==1&&unreadCount>0
              ?Badge(label:Text(unreadCount>49?'49+':'$unreadCount'),
                child:Icon(ReachAdaptiveNavigation.activeIcons[i]))
              :Icon(ReachAdaptiveNavigation.activeIcons[i]),
            label:Text(ReachAdaptiveNavigation.labels[i],
              style:const TextStyle(fontSize:10)),
          ),
      ],
    );
  }
}

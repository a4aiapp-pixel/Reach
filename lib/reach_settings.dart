import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reach_avatar.dart';
import 'reach_call_preferences.dart';
import 'reach_media_prefs.dart';
import 'reach_privacy_preferences.dart';
import 'reach_themes.dart';
import 'repository.dart';

/// Main Settings stays intentionally short. Each feature owns its related
/// controls in a dedicated, searchable submenu; routes preserve Android back.
enum ReachSettingsArea {
  profile,appearance,chats,calls,groups,privacy,account
}

class ReachSettingsActions {
  const ReachSettingsActions({
    required this.viewProfile,required this.editProfile,
    required this.manageGroups,required this.blockedMembers,
    required this.business,required this.assist,required this.legal,
    required this.support,required this.signOut,required this.deleteAccount,
  });
  final VoidCallback viewProfile;
  final Future<void> Function() editProfile;
  final VoidCallback manageGroups,blockedMembers,business,assist,
    legal,support,signOut,deleteAccount;
}

class ReachSettingsHub extends StatefulWidget {
  const ReachSettingsHub({super.key,
    required this.profile,required this.onProfileChanged,
    required this.themeMode,required this.onTheme,
    required this.lookId,required this.onLook,
    required this.callingEnabled,required this.pushEnabled,
    required this.actions,this.initialSection});
  final Map<String,dynamic> profile;
  final VoidCallback onProfileChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onTheme;
  final String lookId;
  final ValueChanged<String> onLook;
  final bool callingEnabled,pushEnabled;
  final ReachSettingsActions actions;
  final ReachSettingsArea? initialSection;
  @override State<ReachSettingsHub> createState()=>_ReachSettingsHubState();
}

class _ReachSettingsHubState extends State<ReachSettingsHub> {
  late ThemeMode mode=widget.themeMode;
  late String lookId=widget.lookId;
  String query='';

  static const labels=<ReachSettingsArea,String>{
    ReachSettingsArea.profile:'Profile',
    ReachSettingsArea.appearance:'Appearance',
    ReachSettingsArea.chats:'Chats & media',
    ReachSettingsArea.calls:'Calls',
    ReachSettingsArea.groups:'Groups',
    ReachSettingsArea.privacy:'Privacy & security',
    ReachSettingsArea.account:'Help & account',
  };
  static const descriptions=<ReachSettingsArea,String>{
    ReachSettingsArea.profile:'Identity, profile picture & discovery',
    ReachSettingsArea.appearance:'Themes, colors & display',
    ReachSettingsArea.chats:'Messages, downloads & notifications',
    ReachSettingsArea.calls:'Consent, quality & connection',
    ReachSettingsArea.groups:'Membership & invitations',
    ReachSettingsArea.privacy:'Blocked people & safety',
    ReachSettingsArea.account:'Support, sign out & account removal',
  };
  static const icons=<ReachSettingsArea,IconData>{
    ReachSettingsArea.profile:Icons.account_circle_outlined,
    ReachSettingsArea.appearance:Icons.palette_outlined,
    ReachSettingsArea.chats:Icons.chat_bubble_outline,
    ReachSettingsArea.calls:Icons.call_outlined,
    ReachSettingsArea.groups:Icons.groups_outlined,
    ReachSettingsArea.privacy:Icons.shield_outlined,
    ReachSettingsArea.account:Icons.support_agent_outlined,
  };
  static const searchKeys=<ReachSettingsArea,String>{
    ReachSettingsArea.profile:'avatar about edit bio skills user discover public private location',
    ReachSettingsArea.appearance:'theme design studio dark light customize fonts layout',
    ReachSettingsArea.chats:'media photo download auto wifi roaming mobile file audio video notification',
    ReachSettingsArea.calls:'voice video network call data adaptive quality reconnect',
    ReachSettingsArea.groups:'add members invite joining permission group management',
    ReachSettingsArea.privacy:'block blocked report safety policy privacy',
    ReachSettingsArea.account:'help support ai assist business delete logout sign out',
  };

  @override void initState(){
    super.initState();
    if(widget.initialSection!=null){
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted)_open(widget.initialSection!);
      });
    }
  }
  @override void didUpdateWidget(covariant ReachSettingsHub oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.themeMode!=widget.themeMode)mode=widget.themeMode;
    if(oldWidget.lookId!=widget.lookId)lookId=widget.lookId;
  }

  void _changeMode(ThemeMode next){
    setState(()=>mode=next);
    widget.onTheme(next);
  }
  void _changeLook(String next){
    setState(()=>lookId=next);
    widget.onLook(next);
  }

  Widget _item(ReachSettingsArea area)=>Card(
    margin:const EdgeInsets.only(bottom:5),
    child:ListTile(
      key:ValueKey('settings-${area.name}'),
      leading:Icon(icons[area]),
      title:Text(labels[area]!),
      subtitle:Text(descriptions[area]!,
        maxLines:1,overflow:TextOverflow.ellipsis),
      trailing:const Icon(Icons.chevron_right_rounded),
      onTap:()=>_open(area),
    ));

  void _open(ReachSettingsArea area){
    Navigator.push(context,MaterialPageRoute(
      settings:RouteSettings(name:'/settings/${area.name}'),
      builder:(_)=>_ReachSettingsDetail(
        area:area,title:labels[area]!,profile:widget.profile,
        onProfileChanged:widget.onProfileChanged,
        actions:widget.actions,
        callingEnabled:widget.callingEnabled,
        pushEnabled:widget.pushEnabled,
        themeMode:mode,onTheme:_changeMode,
        lookId:lookId,onLook:_changeLook,
      ),
    ));
  }

  @override Widget build(BuildContext context){
    final q=query.toLowerCase().trim();
    final results=ReachSettingsArea.values.where((area)=>
      q.isEmpty ||
      labels[area]!.toLowerCase().contains(q) ||
      descriptions[area]!.toLowerCase().contains(q) ||
      searchKeys[area]!.contains(q)).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('Settings')),
      body:SafeArea(child:ListView(
        padding:const EdgeInsets.fromLTRB(15,12,15,30),children:[
        TextField(
          onChanged:(v)=>setState(()=>query=v),
          textInputAction:TextInputAction.search,
          decoration:const InputDecoration(
            hintText:'Find a setting',
            prefixIcon:Icon(Icons.search_rounded),
            isDense:true)),
        const SizedBox(height:13),
        if(results.isEmpty)
          const Padding(padding:EdgeInsets.all(22),
            child:Center(child:Text('No matching settings')))
        else ...results.map(_item),
      ])),
    );
  }
}

class _ReachSettingsDetail extends StatefulWidget {
  const _ReachSettingsDetail({
    required this.area,required this.title,
    required this.profile,required this.onProfileChanged,
    required this.actions,
    required this.callingEnabled,required this.pushEnabled,
    required this.themeMode,required this.onTheme,
    required this.lookId,required this.onLook,
  });
  final ReachSettingsArea area;
  final String title;
  final Map<String,dynamic> profile;
  final VoidCallback onProfileChanged;
  final ReachSettingsActions actions;
  final bool callingEnabled,pushEnabled;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onTheme;
  final String lookId;
  final ValueChanged<String> onLook;
  @override State<_ReachSettingsDetail> createState()=>_ReachSettingsDetailState();
}

class _ReachSettingsDetailState extends State<_ReachSettingsDetail>{
  late ThemeMode mode=widget.themeMode;
  late String look=widget.lookId;

  static const profileKeys={
    'people_discoverable','profile_visibility','location_opt_in',
  };
  static const chatKeys={'allow_media_messages','notify_on'};
  static const callKeys={'allow_calls'};
  static const groupKeys={'allow_group_invites','allow_group_direct_add'};

  Widget _link(IconData icon,String label,VoidCallback tap,{String? subtitle,
      bool destructive=false}){
    final color=destructive?Theme.of(context).colorScheme.error:null;
    return Card(margin:const EdgeInsets.only(bottom:6),
      child:ListTile(
        leading:Icon(icon,color:color),
        title:Text(label,style:TextStyle(color:color)),
        subtitle:subtitle==null?null:Text(subtitle,
          maxLines:2,overflow:TextOverflow.ellipsis),
        trailing:const Icon(Icons.chevron_right),
        onTap:tap));
  }

  Widget _privacy(Set<String> keys)=>_ReachFreshPrivacyPanel(
    key:ValueKey('privacy-${widget.area.name}'),
    initial:widget.profile,
    visibleKeys:keys,
    callingEnabled:widget.callingEnabled,
    pushEnabled:widget.pushEnabled,
    onChanged:widget.onProfileChanged,
  );

  Widget _appearance(){
    return Column(children:[
      Card(child:Padding(padding:const EdgeInsets.fromLTRB(16,13,16,15),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Display mode',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:12),
          SingleChildScrollView(
            scrollDirection:Axis.horizontal,
            child:SegmentedButton<ThemeMode>(
            showSelectedIcon:false,
            segments:const [
              ButtonSegment(value:ThemeMode.system,
                icon:Icon(Icons.phone_android_outlined),label:Text('System')),
              ButtonSegment(value:ThemeMode.light,
                icon:Icon(Icons.light_mode_outlined),label:Text('Light')),
              ButtonSegment(value:ThemeMode.dark,
                icon:Icon(Icons.dark_mode_outlined),label:Text('Dark')),
            ],
            selected:{mode},onSelectionChanged:(v){
              if(v.isEmpty)return;
              setState(()=>mode=v.first);
              widget.onTheme(v.first);
            }),
          ),
        ]))),
      _link(Icons.auto_awesome_mosaic_outlined,'Theme gallery',
        ()async{
          await Navigator.push(context,MaterialPageRoute(
            builder:(_)=>ReachThemeGallery(selected:look,
              onSelected:(id){
                setState(()=>look=id);
                widget.onLook(id);
              })));
        },subtitle:reachLookById(look).name),
    ]);
  }

  @override Widget build(BuildContext context) {
    final sections=<Widget>[];
    switch(widget.area){
      case ReachSettingsArea.profile:
        sections.addAll([
          Card(child:ListTile(
            leading:ReachAvatar(
              name:'${widget.profile['display_name']??'Reach member'}',
              path:widget.profile['avatar_path'] as String?,
              color:'${widget.profile['avatar_color']??'indigo'}',
              size:52),
            title:Text('${widget.profile['display_name']??'Reach member'}'),
            subtitle:Text('@${widget.profile['username']??''}'),
            trailing:const Icon(Icons.chevron_right),
            onTap:widget.actions.viewProfile)),
          const SizedBox(height:6),
          _link(Icons.edit_outlined,'Edit profile',
            ()=>unawaited(widget.actions.editProfile())),
          _link(Icons.business_center_outlined,'Professional profile',
            widget.actions.business),
          const SizedBox(height:8),
          _privacy(profileKeys),
        ]);
      case ReachSettingsArea.appearance:
        sections.add(_appearance());
      case ReachSettingsArea.chats:
        sections.addAll([
          _privacy(chatKeys),
          const SizedBox(height:8),
          _link(Icons.download_for_offline_outlined,'Media downloads',
            ()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const ReachMediaSettingsPage())),
            subtitle:'Mobile data, Wi-Fi and roaming'),
        ]);
      case ReachSettingsArea.calls:
        sections.addAll([
          _privacy(callKeys),
          const SizedBox(height:8),
          _link(Icons.tune_outlined,'Call quality & network',
            ()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const ReachCallSettingsPage())),
            subtitle:'Data saver, video quality and reconnection'),
        ]);
      case ReachSettingsArea.groups:
        sections.addAll([
          _privacy(groupKeys),
          const SizedBox(height:8),
          _link(Icons.groups_rounded,'Manage my groups',
            widget.actions.manageGroups,
            subtitle:'Members, invitations and workspaces'),
        ]);
      case ReachSettingsArea.privacy:
        sections.addAll([
          _link(Icons.block_outlined,'Blocked people',widget.actions.blockedMembers),
          _link(Icons.policy_outlined,'Privacy policy & community rules',
            widget.actions.legal),
        ]);
      case ReachSettingsArea.account:
        sections.addAll([
          _link(Icons.auto_awesome_outlined,'Reach Assist',widget.actions.assist),
          _link(Icons.help_outline,'Help & support',widget.actions.support),
          const SizedBox(height:12),
          _link(Icons.logout_rounded,'Sign out',widget.actions.signOut),
          _link(Icons.delete_forever_outlined,'Delete account',
            widget.actions.deleteAccount,destructive:true),
          const SizedBox(height:10),
          Center(child:Text('Reach 1.4.0',
            style:Theme.of(context).textTheme.labelSmall)),
        ]);
    }
    return Scaffold(
      appBar:AppBar(title:Text(widget.title)),
      body:SafeArea(child:ListView(
        padding:const EdgeInsets.fromLTRB(15,12,15,24),
        children:sections)),
    );
  }
}

/// Always retrieve up-to-date server preferences before editing a category.
/// This prevents stale toggles after moving between independent submenus.
class _ReachFreshPrivacyPanel extends StatefulWidget{
  const _ReachFreshPrivacyPanel({super.key,
    required this.initial,required this.visibleKeys,
    required this.callingEnabled,required this.pushEnabled,
    required this.onChanged});
  final Map<String,dynamic> initial;
  final Set<String> visibleKeys;
  final bool callingEnabled,pushEnabled;
  final VoidCallback onChanged;
  @override State<_ReachFreshPrivacyPanel> createState()=>_ReachFreshPrivacyPanelState();
}
class _ReachFreshPrivacyPanelState extends State<_ReachFreshPrivacyPanel>{
  late Future<Map<String,dynamic>> profile=_load();
  Future<Map<String,dynamic>> _load() async{
    return ReachRepository(Supabase.instance.client)
      .profile().timeout(const Duration(seconds:18));
  }
  void _retry(){setState(()=>profile=_load());}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:profile,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done){
        return const Padding(padding:EdgeInsets.all(18),
          child:Center(child:CircularProgressIndicator()));
      }
      if(snapshot.hasError){
        return Card(child:ListTile(
          leading:const Icon(Icons.wifi_off_outlined),
          title:const Text('Could not load preferences'),
          subtitle:const Text('Check connection and retry'),
          trailing:IconButton(icon:const Icon(Icons.refresh_rounded),
            tooltip:'Retry',onPressed:_retry)));
      }
      return ReachPrivacyPreferences(
        profile:snapshot.data??widget.initial,
        visibleKeys:widget.visibleKeys,
        onChanged:widget.onChanged,
        callingEnabled:widget.callingEnabled,
        pushEnabled:widget.pushEnabled,
      );
    });
}

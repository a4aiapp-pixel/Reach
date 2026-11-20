import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'repository.dart';
import 'reach_experience.dart';
import 'reach_themes.dart';

/// A real, private-by-membership workspace for every group. Invite codes,
/// realtime discussion, group-only reaches, resource links/notes and roster
/// all use authenticated server endpoints with membership enforcement.
class ReachGroupWorkspace extends StatefulWidget {
  const ReachGroupWorkspace({super.key,required this.group,
    required this.onCompose,required this.onOpenReach});
  final Map<String,dynamic> group;
  final Future<void> Function(String groupId) onCompose;
  final Future<void> Function(ReachPost post) onOpenReach;
  @override State<ReachGroupWorkspace> createState()=>_ReachGroupWorkspaceState();
}

class _ReachGroupWorkspaceState extends State<ReachGroupWorkspace> {
  final api=ReachRepository(Supabase.instance.client);
  final input=TextEditingController();
  late final String groupId;
  late final Stream<List<Map<String,dynamic>>> conversation;
  late Map<String,dynamic> group;
  List<ReachPost> posts=[];
  List<Map<String,dynamic>> members=[],resources=[];
  bool loading=true,sending=false;
  String? error;

  String get name=>_s(group['name']);
  String get code=>_s(group['invite_code']);
  String _s(dynamic value)=>value?.toString()??'';

  @override void initState(){
    super.initState();
    group=Map<String,dynamic>.from(widget.group);
    groupId=_s(group['id']);
    conversation=api.groupMessages(groupId);
    unawaited(refresh());
  }
  @override void dispose(){input.dispose();super.dispose();}

  Future<void> refresh() async{
    if(!mounted)return;
    setState((){loading=true;error=null;});
    try{
      final rows=await Future.wait<Object>([
        api.groupPosts(groupId),
        api.groupResources(groupId),
        api.groupMembers(groupId),
      ]).timeout(const Duration(seconds:22));
      if(!mounted)return;
      setState((){
        posts=rows[0] as List<ReachPost>;
        resources=rows[1] as List<Map<String,dynamic>>;
        members=rows[2] as List<Map<String,dynamic>>;
      });
    }catch(e){
      if(mounted)setState(()=>error=_error(e));
    }finally{if(mounted)setState(()=>loading=false);}
  }
  String _error(Object error){
    final s=error.toString().replaceFirst('Exception: ','')
      .replaceFirst('Bad state: ','');
    if(error is TimeoutException || s.contains('SocketException')){
      return 'Connection timed out. Check your network and retry.';
    }
    if(error is PostgrestException)return error.message;
    return s;
  }
  void notice(Object e){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(_error(e)),behavior:SnackBarBehavior.floating));
  }

  Future<void> copyInvite() async{
    if(code.isEmpty){notice(StateError('Invite code is not available. Refresh the group.'));return;}
    await Clipboard.setData(ClipboardData(text:code));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('Invitation code copied')));
  }
  Future<void> shareInvite()async{
    if(code.isEmpty){notice(StateError('Invite code is not available. Refresh the group.'));return;}
    await SharePlus.instance.share(ShareParams(
      text:'Join my Reach group "$name". Open Reach → Groups → Join by code, then enter: $code'));
  }
  Future<void> rotateInvite() async {
    if(group['owner_id']!=api.uid)return;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Replace invitation code?'),
      content:const Text('The old code will stop working immediately. '
        'Existing group members will remain in the group.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Replace code')),
      ]));
    if(confirmed!=true||!mounted)return;
    try{
      final next=await api.rotateGroupInvite(groupId);
      if(!mounted)return;
      setState(()=>group['invite_code']=next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('New invitation code is ready to share.')));
    }catch(e){notice(e);}
  }

  Future<void> send() async {
    final body=input.text.trim();
    if(body.isEmpty || sending)return;
    setState(()=>sending=true);
    try{
      await api.sendGroupMessage(groupId,body).timeout(const Duration(seconds:20));
      if(mounted)input.clear();
    }catch(e){notice(e);}
    finally{if(mounted)setState(()=>sending=false);}
  }

  Future<void> composeResource() async {
    final title=TextEditingController(),note=TextEditingController(),
      url=TextEditingController();
    String kind='note';
    final key=GlobalKey<FormState>();
    final request=await showDialog<Map<String,String>>(
      context:context,builder:(ctx)=>StatefulBuilder(
        builder:(ctx,repaint)=>AlertDialog(
          title:const Text('Share a group resource'),
          content:SizedBox(width:440,child:Form(key:key,
            child:SingleChildScrollView(child:Column(
              mainAxisSize:MainAxisSize.min,children:[
              DropdownButtonFormField<String>(
                initialValue:kind,
                decoration:const InputDecoration(labelText:'Resource type'),
                items:const [
                  DropdownMenuItem(value:'note',child:Text('Note or guidance')),
                  DropdownMenuItem(value:'link',child:Text('Website / link')),
                ],
                onChanged:(v)=>repaint(()=>kind=v??'note')),
              const SizedBox(height:12),
              TextFormField(controller:title,maxLength:100,
                textCapitalization:TextCapitalization.sentences,
                decoration:const InputDecoration(labelText:'Resource title'),
                validator:(s)=>(s??'').trim().length<3?'Enter at least 3 characters':null),
              const SizedBox(height:8),
              TextFormField(controller:note,maxLength:3000,maxLines:3,
                decoration:const InputDecoration(labelText:'Description / notes')),
              if(kind=='link')...[
                const SizedBox(height:8),
                TextFormField(controller:url,maxLength:1024,
                  keyboardType:TextInputType.url,
                  decoration:const InputDecoration(
                    labelText:'HTTPS link',hintText:'https://example.com/...'),
                  validator:(raw){
                    final parsed=Uri.tryParse((raw??'').trim());
                    if(parsed==null||parsed.scheme!='https'||!parsed.hasAuthority||
                        parsed.host.isEmpty)return 'Enter a valid HTTPS address';
                    return null;
                  }),
              ],
              const SizedBox(height:6),
              Text('Resources are visible only to group members. '
                'Never share passwords, verification codes or private addresses.',
                style:Theme.of(ctx).textTheme.bodySmall),
            ])))),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
            FilledButton.icon(onPressed:(){
              if(!key.currentState!.validate())return;
              Navigator.pop(ctx,{
                'title':title.text.trim(),'note':note.text.trim(),
                if(kind=='link')'url':url.text.trim(),
              });
            },icon:const Icon(Icons.add),label:const Text('Share')),
          ],
        )));
    title.dispose();note.dispose();url.dispose();
    if(request==null||!mounted)return;
    try{
      await api.shareGroupResource(groupId,
        title:request['title']!,note:request['note']!,
        url:request['url']);
      if(mounted){await refresh();}
    }catch(e){notice(e);}
  }

  Future<void> deleteResource(Map<String,dynamic> resource) async{
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('Remove this resource?'),
        content:const Text('This shared note or link will be removed from the group.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Remove')),
        ]));
    if(confirmed!=true||!mounted)return;
    try{
      await api.removeGroupResource(_s(resource['id']));
      await refresh();
    }catch(e){notice(e);}
  }

  Future<void> reportContent(String type,String id) async {
    String reason='spam';
    final detail=TextEditingController();
    final accepted=await showDialog<bool>(context:context,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,repaint)=>AlertDialog(
        title:const Text('Report group content'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Only report genuine safety or community-rule concerns.'),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            initialValue:reason,
            decoration:const InputDecoration(labelText:'Reason'),
            items:const [
              DropdownMenuItem(value:'spam',child:Text('Spam')),
              DropdownMenuItem(value:'harassment',child:Text('Harassment')),
              DropdownMenuItem(value:'unsafe',child:Text('Unsafe content')),
              DropdownMenuItem(value:'fraud',child:Text('Fraud or scam')),
              DropdownMenuItem(value:'other',child:Text('Other')),
            ],
            onChanged:(value)=>repaint(()=>reason=value??'spam')),
          const SizedBox(height:9),
          TextField(controller:detail,maxLines:3,maxLength:500,
            decoration:const InputDecoration(labelText:'Additional details (optional)')),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Submit report')),
        ],
      )));
    final note=detail.text.trim();
    detail.dispose();
    if(accepted!=true || !mounted)return;
    try{
      await api.report(type,id,reason,note);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Report sent for review.')));
    }catch(e){notice(e);}
  }

  Widget empty(IconData icon,String title,String detail)=>
    Center(child:Padding(padding:const EdgeInsets.all(26),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,size:48,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:12),
        Text(title,textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:6),
        Text(detail,textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.bodySmall),
      ])));

  Widget inviteStrip(){
    final owner=group['owner_id']==api.uid;
    return Card(child:Padding(padding:const EdgeInsets.all(13),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.key_outlined,size:20),
          const SizedBox(width:8),
          Expanded(child:Text('Your group invitation code',
            style:Theme.of(context).textTheme.titleSmall)),
          if(owner)PopupMenuButton<String>(
            tooltip:'Invite management',
            onSelected:(value){if(value=='rotate')unawaited(rotateInvite());},
            itemBuilder:(_)=>const [
              PopupMenuItem(value:'rotate',child:Text('Reset invitation code')),
            ]),
        ]),
        const SizedBox(height:7),
        Row(children:[
          Expanded(child:SelectableText(code.isEmpty?'Loading…':code,
            style:Theme.of(context).textTheme.titleLarge?.copyWith(
              letterSpacing:2,fontWeight:FontWeight.w800))),
          IconButton(tooltip:'Copy invitation code',onPressed:copyInvite,
            icon:const Icon(Icons.copy_all_outlined)),
          FilledButton.tonalIcon(onPressed:shareInvite,
            icon:const Icon(Icons.share_outlined),label:const Text('Invite')),
        ]),
        const SizedBox(height:3),
        Text('Invite any trusted Reach member to join via Groups → Join by code.',
          style:Theme.of(context).textTheme.bodySmall),
      ])));
  }

  Widget discussion(){
    return Column(children:[
      Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(
        stream:conversation,builder:(ctx,snapshot){
          if(snapshot.hasError)return empty(Icons.wifi_off_outlined,
            'Group discussion unavailable',_error(snapshot.error!));
          if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
          final entries=snapshot.data!;
          if(entries.isEmpty)return empty(Icons.forum_outlined,
            'Start your group discussion','Introduce yourself or share an update.');
          return ListView.builder(
            padding:const EdgeInsets.fromLTRB(14,8,14,16),
            itemCount:entries.length,
            itemBuilder:(ctx,index){
              final m=entries[index];
              final mine=m['sender_id']==api.uid;
              return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,
                child:ConstrainedBox(
                  constraints:BoxConstraints(
                    maxWidth:MediaQuery.sizeOf(ctx).width*.83),
                  child:Card(color:mine?Theme.of(ctx).colorScheme.primaryContainer:null,
                    shape:RoundedRectangleBorder(
                      borderRadius:BorderRadius.only(
                        topLeft:Radius.circular(ReachDesign.of(ctx).radius),
                        topRight:Radius.circular(ReachDesign.of(ctx).radius),
                        bottomLeft:Radius.circular(mine?ReachDesign.of(ctx).radius:4),
                        bottomRight:Radius.circular(mine?4:ReachDesign.of(ctx).radius))),
                    child:Padding(padding:const EdgeInsets.all(12),child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(mine?'You':_s(m['sender_name']),
                        style:Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          fontWeight:FontWeight.w800)),
                      const SizedBox(height:4),
                      Text(_s(m['body']),style:Theme.of(ctx).textTheme.bodyMedium),
                      if(!mine)Align(alignment:Alignment.centerRight,
                        child:IconButton(
                          tooltip:'Report group message',
                          onPressed:()=>reportContent(
                            'group_message',_s(m['id'])),
                          icon:const Icon(Icons.flag_outlined,size:16),
                          visualDensity:VisualDensity.compact)),
                    ]))))));
            });
        })),
      SafeArea(top:false,child:Padding(
        padding:const EdgeInsets.fromLTRB(10,5,8,10),
        child:Row(children:[
          Expanded(child:TextField(
            controller:input,minLines:1,maxLines:4,maxLength:2000,
            textCapitalization:TextCapitalization.sentences,
            decoration:const InputDecoration(
              hintText:'Message group members',counterText:''),
            onSubmitted:(_)=>unawaited(send()))),
          IconButton(tooltip:'Send group message',
            onPressed:sending?null:send,
            icon:sending?const SizedBox(width:19,height:19,
              child:CircularProgressIndicator(strokeWidth:2)):
              const Icon(Icons.send_rounded)),
        ]))),
    ]);
  }

  Widget reaches(){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(error!=null)return empty(Icons.error_outline,'Could not open group posts',error!);
    return RefreshIndicator(onRefresh:refresh,
      child:ListView(padding:const EdgeInsets.all(15),children:[
        Row(children:[
          Expanded(child:Text('Member-only offers & requests',
            style:Theme.of(context).textTheme.titleMedium)),
          FilledButton.tonalIcon(
            onPressed:()async{await widget.onCompose(groupId);await refresh();},
            icon:const Icon(Icons.add),label:const Text('Post')),
        ]),
        const SizedBox(height:10),
        if(posts.isEmpty)empty(Icons.campaign_outlined,'No group posts yet',
          'Create an offer or request for members of this group.')
        else for(final item in posts)
          Card(child:ListTile(
            title:Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis),
            subtitle:Text('${item.kind=='offer'?'Offering':'Requesting'} · '
              '${item.ownerName} · ${item.category}',
              maxLines:2,overflow:TextOverflow.ellipsis),
            leading:Icon(item.kind=='offer'?Icons.volunteer_activism_outlined:
              Icons.pan_tool_alt_outlined),
            trailing:const Icon(Icons.chevron_right),
            onTap:()async{await widget.onOpenReach(item);await refresh();},
          )),
      ])));
  }

  Widget resourceList(){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(error!=null)return empty(Icons.error_outline,'Could not load resources',error!);
    return RefreshIndicator(onRefresh:refresh,
      child:ListView(padding:const EdgeInsets.all(15),children:[
        Row(children:[
          Expanded(child:Text('Resources & shared knowledge',
            style:Theme.of(context).textTheme.titleMedium)),
          FilledButton.tonalIcon(onPressed:composeResource,
            icon:const Icon(Icons.add),label:const Text('Share')),
        ]),
        const SizedBox(height:10),
        if(resources.isEmpty)empty(Icons.bookmarks_outlined,'No shared resources',
          'Members can share useful HTTPS links or written notes.')
        else for(final item in resources)
          Card(child:ListTile(
            leading:Icon(item['kind']=='link'?
              Icons.link_rounded:Icons.note_outlined),
            title:Text(_s(item['title'])),
            subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              if(_s(item['note']).isNotEmpty)
                Text(_s(item['note']),maxLines:3,overflow:TextOverflow.ellipsis),
              Text('Shared by ${_s(item['creator_name'])}',
                style:Theme.of(context).textTheme.labelSmall),
              if(item['kind']=='link')Text(_s(item['url']),
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:Theme.of(context).colorScheme.primary)),
            ]),
            isThreeLine:true,
            trailing:PopupMenuButton<String>(
              tooltip:'Resource actions',
              onSelected:(action)async{
                if(action=='remove')await deleteResource(item);
                if(action=='report')await reportContent(
                  'group_resource',_s(item['id']));
              },
              itemBuilder:(_)=>[
                if(item['creator_id']==api.uid||
                    group['owner_id']==api.uid)
                  const PopupMenuItem(value:'remove',
                    child:Text('Remove resource')),
                if(item['creator_id']!=api.uid)
                  const PopupMenuItem(value:'report',
                    child:Text('Report resource')),
              ],
              icon:const Icon(Icons.more_vert)),

            onTap:item['kind']=='link'?()async{
              final uri=Uri.tryParse(_s(item['url']));
              if(uri!=null&&uri.scheme=='https'){
                if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
                  notice(StateError('Could not open this link.'));
                }
              }
            }:null,
          )),
      ])));
  }

  Widget roster(){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(error!=null)return empty(Icons.error_outline,'Could not load members',error!);
    return RefreshIndicator(onRefresh:refresh,
      child:ListView(padding:const EdgeInsets.all(15),children:[
        Text('${members.length} group member${members.length==1?'':'s'}',
          style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:9),
        for(final item in members)
          Card(child:ListTile(
            leading:CircleAvatar(child:Text(_s(item['display_name']).isEmpty?
              '?':_s(item['display_name']).characters.first.toUpperCase())),
            title:Text(_s(item['display_name'])),
            subtitle:Text(_s(item['role'])),
            trailing:item['user_id']==api.uid?
              const Chip(label:Text('You')):null,
          )),
      ])));
  }

  @override Widget build(BuildContext context)=>DefaultTabController(
    length:4,child:Scaffold(
      appBar:AppBar(title:Text(name,maxLines:1,overflow:TextOverflow.ellipsis),
        actions:[
          IconButton(tooltip:'Share group invitation',
            onPressed:shareInvite,icon:const Icon(Icons.person_add_alt_outlined)),
          IconButton(tooltip:'Refresh group',onPressed:refresh,
            icon:const Icon(Icons.refresh_rounded)),
        ]),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(13,4,13,4),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            ReachExperienceHeader(title:name,
              subtitle:'${_s(group['category'])} · ${_s(group['visibility'])} group',
              icon:Icons.groups_2_outlined),
            if(_s(group['description']).isNotEmpty)
              Padding(padding:const EdgeInsets.only(top:7,bottom:3),
                child:Text(_s(group['description']),maxLines:2,
                  overflow:TextOverflow.ellipsis)),
            const SizedBox(height:5),
            Card(child:ExpansionTile(
              leading:const Icon(Icons.person_add_alt_1_outlined),
              title:const Text('Invite members'),
              subtitle:Text(code.isEmpty?'Open for invitation options':code,
                maxLines:1,overflow:TextOverflow.ellipsis),
              children:[Padding(
                padding:const EdgeInsets.fromLTRB(8,0,8,8),
                child:inviteStrip())],
            )),
          ])),
        const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,
          tabs:[
            Tab(icon:Icon(Icons.forum_outlined),text:'Discussion'),
            Tab(icon:Icon(Icons.volunteer_activism_outlined),text:'Reaches'),
            Tab(icon:Icon(Icons.folder_open_outlined),text:'Resources'),
            Tab(icon:Icon(Icons.people_outline),text:'Members'),
          ]),
        Expanded(child:TabBarView(children:[
          discussion(),reaches(),resourceList(),roster(),
        ])),
      ])),
    ));
}

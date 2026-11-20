import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reach_avatar.dart';
import 'repository.dart';

/// Real member addition, not a duplicate share sheet. Direct-add needs an
/// explicit recipient opt-in; otherwise send a request for their approval.
class ReachGroupAddMemberPage extends StatefulWidget {
  const ReachGroupAddMemberPage({super.key,required this.circleId,
    required this.groupName});
  final String circleId,groupName;
  @override State<ReachGroupAddMemberPage> createState()=>_ReachGroupAddMemberPageState();
}
class _ReachGroupAddMemberPageState extends State<ReachGroupAddMemberPage>{
  final api=ReachRepository(Supabase.instance.client);
  final search=TextEditingController(),identity=TextEditingController();
  Timer? debounce;
  List<Map<String,dynamic>> candidates=[];
  bool busy=false,loading=false;
  String? failure,result;
  int revision=0;
  @override void initState(){super.initState();unawaited(refresh());}
  @override void dispose(){
    debounce?.cancel();search.dispose();identity.dispose();super.dispose();
  }
  Future<void> refresh()async{
    final ticket=++revision;
    setState(()=>loading=true);
    try{
      final data=await api.groupCandidates(widget.circleId,search.text)
        .timeout(const Duration(seconds:20));
      if(mounted&&ticket==revision){
        setState((){candidates=data;failure=null;});
      }
    }catch(e){if(mounted&&ticket==revision)setState(()=>failure=e.toString());}
    finally{if(mounted&&ticket==revision)setState(()=>loading=false);}
  }
  Future<void> add(String who,{bool inviteOnly=false})async{
    if(who.trim().length<3||busy)return;
    setState((){busy=true;result=null;failure=null;});
    try{
      final status=await api.addGroupMember(widget.circleId,who,
        inviteOnly:inviteOnly).timeout(const Duration(seconds:23));
      if(!mounted)return;
      setState(()=>result=switch(status){
        'added'=>'Member added to ${widget.groupName}!',
        'invited'=>'Invitation sent for approval.',
        'already_member'=>'This person already belongs to the group.',
        _=>'Request processed where the recipient permits invitations.',
      });
      identity.clear();
      await refresh();
    }catch(e){if(mounted)setState(()=>failure=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context){
    final theme=Theme.of(context),scheme=theme.colorScheme;
    return Scaffold(
      appBar:AppBar(title:Text('Add to ${widget.groupName}',
        maxLines:1,overflow:TextOverflow.ellipsis)),
      body:SafeArea(child:ListView(
        padding:const EdgeInsets.fromLTRB(16,12,16,70),children:[
          Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Add by username, ID or email',
              style:theme.textTheme.titleMedium),
            const SizedBox(height:12),
            TextField(controller:identity,
              autocorrect:false,
              keyboardType:TextInputType.emailAddress,
              decoration:const InputDecoration(
                hintText:'@username, account ID or email',
                prefixIcon:Icon(Icons.person_search_outlined)),
              onSubmitted:(v)=>add(v)),
            const SizedBox(height:10),
            Row(children:[
              Expanded(child:FilledButton.icon(
                onPressed:busy?null:()=>add(identity.text),
                icon:const Icon(Icons.person_add_alt_1_rounded),
                label:const Text('Add member'))),
              const SizedBox(width:9),
              Expanded(child:OutlinedButton.icon(
                onPressed:busy?null:()=>add(identity.text,inviteOnly:true),
                icon:const Icon(Icons.mail_outline),
                label:const Text('Send invite'))),
            ]),
          ]))),
          const SizedBox(height:12),
          if(result!=null)AnimatedSwitcher(
            duration:const Duration(milliseconds:350),
            child:Card(key:ValueKey(result),
              color:scheme.primaryContainer,
              child:ListTile(
                leading:const Icon(Icons.celebration_rounded),
                title:Text(result!),trailing:const Icon(Icons.check_circle)))),
          if(failure!=null)Card(child:ListTile(
            leading:Icon(Icons.error_outline,color:scheme.error),
            title:const Text('Could not complete the request'),
            subtitle:Text(failure!),trailing:IconButton(
              tooltip:'Retry',onPressed:()=>add(identity.text),
              icon:const Icon(Icons.refresh)))),
          const SizedBox(height:18),
          Text('Find members',style:theme.textTheme.titleLarge),
          const SizedBox(height:8),
          TextField(controller:search,
            textCapitalization:TextCapitalization.none,
            onChanged:(_){
              debounce?.cancel();
              debounce=Timer(const Duration(milliseconds:350),refresh);
            },
            decoration:const InputDecoration(hintText:'Search names or usernames',
              prefixIcon:Icon(Icons.search_rounded))),
          const SizedBox(height:10),
          if(loading)const LinearProgressIndicator()
          else if(candidates.isEmpty)
            Padding(padding:const EdgeInsets.all(20),
              child:Center(child:Text('No eligible people found.',
                style:theme.textTheme.bodyMedium)))
          else for(final person in candidates)
            Card(child:ListTile(
              leading:ReachAvatar(
                name:'${person['display_name']}',
                path:person['avatar_path'] as String?,
                size:45),
              title:Text('${person['display_name']}',
                maxLines:1,overflow:TextOverflow.ellipsis),
              subtitle:Text('@${person['username']??''} · '
                '${person['allow_direct']==true?'Allows direct add':'Invitation required'}',
                maxLines:2,overflow:TextOverflow.ellipsis),
              trailing:IconButton(
                tooltip:person['allow_direct']==true?'Add now':'Invite',
                onPressed:busy?null:()=>add('${person['id']}'),
                icon:Icon(person['allow_direct']==true?
                  Icons.person_add_alt_1:Icons.mail_outline)),
              onTap:()=>Navigator.push(context,MaterialPageRoute(
                builder:(_)=>ReachMemberProfilePage(
                  memberId:'${person['id']}'))),
            )),
        ])),
    );
  }
}

class ReachGroupInvitations extends StatefulWidget{
  const ReachGroupInvitations({super.key,required this.onJoined});
  final VoidCallback onJoined;
  @override State<ReachGroupInvitations> createState()=>_ReachGroupInvitationsState();
}
class _ReachGroupInvitationsState extends State<ReachGroupInvitations>{
  final api=ReachRepository(Supabase.instance.client);
  bool loading=true,updating=false;
  List<Map<String,dynamic>> invites=[];
  @override void initState(){super.initState();unawaited(refresh());}
  Future<void> refresh()async{
    try{
      final data=await api.groupInvitations()
        .timeout(const Duration(seconds:18));
      if(mounted)setState(()=>invites=data);
    }catch(e){debugPrint('Reach invitations refresh: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> respond(String id,bool accept)async{
    if(updating)return;
    setState(()=>updating=true);
    try{
      await api.answerGroupInvitation(id,accept);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text(accept?'Welcome to your new group!':'Invitation declined.')));
        if(accept)widget.onJoined();
      }
      await refresh();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.toString())));
    }finally{if(mounted)setState(()=>updating=false);}
  }

  @override Widget build(BuildContext context){
    if(loading||invites.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Icon(Icons.mark_email_unread_outlined),
        const SizedBox(width:9),
        Text('Invitations',style:Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        IconButton(tooltip:'Refresh invitations',
          onPressed:refresh,icon:const Icon(Icons.refresh_rounded)),
      ]),
      for(final invite in invites)
        Card(child:Padding(padding:const EdgeInsets.all(9),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            ListTile(
              contentPadding:const EdgeInsets.symmetric(horizontal:6),
              leading:const CircleAvatar(child:Icon(Icons.groups_rounded)),
              title:Text('${invite['group_name']}'),
              subtitle:Text('From ${invite['inviter_name']}'),
            ),
            Row(children:[
              Expanded(child:OutlinedButton(
                onPressed:updating?null:()=>respond('${invite['id']}',false),
                child:const Text('Decline'))),
              const SizedBox(width:9),
              Expanded(child:FilledButton(
                onPressed:updating?null:()=>respond('${invite['id']}',true),
                child:const Text('Join group'))),
            ]),
          ]))),
      const SizedBox(height:13),
    ]);
  }
}

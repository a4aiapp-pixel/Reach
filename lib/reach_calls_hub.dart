import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reach_calling.dart';
import 'reach_experience.dart';
import 'repository.dart';

/// Direct access to calling without first navigating through Chat → Inbox.
/// Only accepted mutual-consent conversations can place a voice/video call.
class ReachCallsHub extends StatefulWidget {
  const ReachCallsHub({super.key,required this.onOpenConversation});
  final void Function(Map<String,dynamic> conversation) onOpenConversation;
  @override State<ReachCallsHub> createState()=>_ReachCallsHubState();
}
class _ReachCallsHubState extends State<ReachCallsHub>{
  final api=ReachRepository(Supabase.instance.client);
  bool loading=true;
  String? error;
  List<Map<String,dynamic>> conversations=[],history=[];
  Map<String,bool> permission={};

  @override void initState(){super.initState();unawaited(refresh());}

  Future<void> refresh()async{
    if(!mounted)return;
    setState((){loading=true;error=null;});
    try{
      final rows=await Future.wait<dynamic>([
        api.conversations(),api.callHistory(),
      ]).timeout(const Duration(seconds:22));
      final conversationsFetched=(rows[0] as List).cast<Map<String,dynamic>>();
      final historyFetched=(rows[1] as List).cast<Map<String,dynamic>>();
      final allowed=<String,bool>{};
      for(final conversation in conversationsFetched.take(50)){
        final peer=(conversation['peer_id']??'').toString();
        if(peer.isEmpty)continue;
        try{
          allowed[peer]=await api.canCall(peer)
            .timeout(const Duration(seconds:10));
        }catch(_){allowed[peer]=false;}
      }
      if(mounted)setState((){
        conversations=conversationsFetched;
        history=historyFetched;
        permission=allowed;
      });
    }catch(e){
      if(mounted)setState(()=>error=e is PostgrestException?
        e.message:e.toString().replaceFirst('Bad state: ',''));
    }finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>SafeArea(
    child:RefreshIndicator(onRefresh:refresh,child:ListView(
      padding:const EdgeInsets.fromLTRB(16,15,16,80),children:[
      ReachExperienceHeader(
        title:'Calls',subtitle:'Voice, video and trusted connections',
        icon:Icons.call_outlined,
        actions:IconButton(tooltip:'Refresh calls',
          onPressed:refresh,icon:const Icon(Icons.refresh_rounded))),
      const SizedBox(height:14),
      if(loading)const Padding(padding:EdgeInsets.all(38),
        child:Center(child:CircularProgressIndicator()))
      else if(error!=null)Card(child:ListTile(
        leading:const Icon(Icons.wifi_off_outlined),
        title:const Text('Could not load calls'),
        subtitle:Text(error!),
        trailing:TextButton(onPressed:refresh,child:const Text('Retry'))))
      else ...[
        Text('People you can call',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        if(conversations.isEmpty)Card(child:Padding(
          padding:const EdgeInsets.all(18),
          child:Column(children:[
            const Icon(Icons.people_outline,size:38),
            const SizedBox(height:10),
            const Text('No accepted connections yet'),
            const SizedBox(height:5),
            Text('Find people, send a connection request and have them accept. '
              'Both people must also allow calls in Me → Privacy.',
              textAlign:TextAlign.center,
              style:Theme.of(context).textTheme.bodySmall),
          ])))
        else for(final c in conversations.take(50))
          Card(child:Padding(padding:const EdgeInsets.all(9),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            ListTile(
              leading:const CircleAvatar(child:Icon(Icons.person_outline)),
              title:Text((c['peer_name']??'Reach member').toString()),
              subtitle:Text(permission[(c['peer_id']??'').toString()]==true
                ?'Available for mutual-consent calling'
                :'Calling requires both members to opt in'),
              trailing:IconButton(tooltip:'Open private chat',
                onPressed:()=>widget.onOpenConversation(c),
                icon:const Icon(Icons.chat_bubble_outline)),
            ),
            if(permission[(c['peer_id']??'').toString()]==true)
              ReachCallActions(conversationId:(c['id']??'').toString(),
                peerId:(c['peer_id']??'').toString(),
                peerName:(c['peer_name']??'Reach member').toString()),
          ]))),
        const SizedBox(height:17),
        Text('Recent calls',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:9),
        if(history.isEmpty)Card(child:const ListTile(
          leading:Icon(Icons.history),
          title:Text('No call history yet'),
          subtitle:Text('Your voice and video calls appear here.')))
        else for(final row in history.take(50))
          Card(child:ListTile(
            leading:Icon(row['kind']=='video'?
              Icons.videocam_outlined:Icons.call_outlined),
            title:Text((row['peer_name']??'Reach member').toString()),
            subtitle:Text('${(row['kind']??'audio').toString()} · '
              '${(row['status']??'').toString()}'),
            trailing:Text(_date(row['created_at']),
              style:Theme.of(context).textTheme.labelSmall),
          )),
      ],
    ])));
  String _date(dynamic value){
    final parsed=DateTime.tryParse((value??'').toString())?.toLocal();
    return parsed==null?'':DateFormat('d MMM, h:mm a').format(parsed);
  }
}

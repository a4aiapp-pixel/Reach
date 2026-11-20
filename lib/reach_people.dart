import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repository.dart';
import 'reach_avatar.dart';

/// People discovery is separate from offers/requests. Nobody is listed
/// unless they explicitly opt in, and private profile details remain hidden
/// until that member accepts a connection.
class ReachPeoplePage extends StatefulWidget {
  const ReachPeoplePage({super.key,required this.chatBuilder});
  final Widget Function(String conversationId,String peerId,String peerName) chatBuilder;
  @override State<ReachPeoplePage> createState()=>_ReachPeoplePageState();
}

class _ReachPeoplePageState extends State<ReachPeoplePage> {
  late final ReachRepository api=ReachRepository(Supabase.instance.client);
  final search=TextEditingController();
  Timer? debounce;
  String area='city';
  bool loading=true;
  int ticket=0;
  List<Map<String,dynamic>> people=[];

  @override void initState(){super.initState();unawaited(refresh());}
  @override void dispose(){debounce?.cancel();search.dispose();super.dispose();}

  void notice(Object value){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(value.toString().replaceFirst('Bad state: ','')
        .replaceFirst('PostgrestException(message: ','')),
      behavior:SnackBarBehavior.floating));
  }

  Future<void> refresh() async {
    if(!mounted)return;
    final serial=++ticket;
    setState(()=>loading=true);
    try{
      final data=await api.discoverPeople(area:area,query:search.text);
      if(mounted&&serial==ticket)setState((){people=data;loading=false;});
    }catch(e){
      if(mounted&&serial==ticket){setState(()=>loading=false);notice(e);}
    }
  }

  Future<void> request(Map<String,dynamic> person) async {
    final controller=TextEditingController();
    final message=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Connect with ${person['display_name']}?'),
      content:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('The other member must approve before you can send messages. '
          'Calling also requires both members to opt in.'),
        const SizedBox(height:12),
        TextField(controller:controller,maxLength:400,maxLines:3,
          decoration:const InputDecoration(labelText:'Brief introduction',
            hintText:'Hello, I would like to connect on Reach.')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
          child:const Text('Send request'))
      ]));
    controller.dispose();
    if(message==null||message.length<2)return;
    try{
      await api.requestMember(person['id'] as String,message);
      notice('Request sent. You can chat after it is accepted.');
      await refresh();
    }catch(e){notice(e);}
  }

  Future<void> report(Map<String,dynamic> person) async {
    final result=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(
      title:const Text('Report member'),
      children:[
        for(final item in const <String,String>{
          'spam':'Spam or unsolicited contact',
          'fraud':'Fraud or impersonation',
          'harassment':'Harassment',
          'adult_content':'Sexual content',
          'child_safety':'Child safety',
          'illegal_content':'Illegal activity',
          'unsafe':'Other unsafe behavior',
        }.entries)
          SimpleDialogOption(
            onPressed:()=>Navigator.pop(ctx,item.key),
            child:Text(item.value)),
      ]));
    if(result==null)return;
    try{
      await api.report('user',person['id'] as String,result,
        'Report submitted from the member directory.');
      notice('Report received for moderator review.');
    }catch(e){notice(e);}
  }

  Future<void> block(Map<String,dynamic> person) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Block member?'),
      content:Text('Block ${person['display_name']}? They will no longer appear '
        'in your discovery results or be able to contact you.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Block'))
      ]));
    if(ok!=true)return;
    try{await api.blockUser(person['id'] as String);await refresh();}
    catch(e){notice(e);}
  }

  Widget personCard(Map<String,dynamic> person){
    final id=person['id'] as String? ?? '';
    final name=(person['display_name'] as String? ?? '').trim();
    final display=name.isEmpty?'Reach member':name;
    final username=person['username'] as String? ?? '';
    final privacy=person['profile_visibility']=='public'?'Public':'Private';
    final status=person['connection_status'] as String? ?? 'none';
    final convo=person['conversation_id'] as String?;
    final bio=person['bio'] as String? ?? '';
    final skills=(person['skills'] as List? ?? []).join(', ');
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(
      padding:const EdgeInsets.all(15),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          ReachAvatar(name:display,
            path:person['avatar_path'] as String?,
            color:person['avatar_color']?.toString()??'indigo',size:45),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(display,style:Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight:FontWeight.w700)),
              if(username.isNotEmpty)Text('@$username',style:Theme.of(context).textTheme.bodySmall),
            ])),
          IconButton(
            tooltip:'View profile',
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>ReachMemberProfilePage(memberId:id))),
            icon:const Icon(Icons.account_circle_outlined)),
          PopupMenuButton<String>(tooltip:'Member safety actions',
            onSelected:(v){if(v=='report')unawaited(report(person));
              if(v=='block')unawaited(block(person));},
            itemBuilder:(_)=>const [
              PopupMenuItem(value:'report',child:Text('Report member')),
              PopupMenuItem(value:'block',child:Text('Block member')),
            ]),
        ]),
        const SizedBox(height:8),
        Text('${person['city']}, ${person['country']}',
          style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:5),
        Text('$privacy profile',style:Theme.of(context).textTheme.labelSmall),
        if(bio.isNotEmpty)...[const SizedBox(height:10),Text(bio)],
        if(skills.isNotEmpty)...[const SizedBox(height:7),
          Text('Skills: $skills',style:Theme.of(context).textTheme.bodySmall)],
        const SizedBox(height:12),
        if(status=='accepted'&&convo!=null)
          FilledButton.icon(
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>widget.chatBuilder(convo,id,display))),
            icon:const Icon(Icons.chat_outlined),label:const Text('Open private chat'))
        else if(status=='none')
          OutlinedButton.icon(onPressed:()=>request(person),
            icon:const Icon(Icons.person_add_alt_1),label:const Text('Request connection'))
        else
          Chip(label:Text(status=='pending'?'Connection pending':
             status=='accepted'?'Connected':'Request declined')),
      ])));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Find people'),
      actions:[IconButton(tooltip:'Refresh people',onPressed:refresh,
        icon:const Icon(Icons.refresh_rounded))]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(17,7,17,11),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const SizedBox(height:5),
          TextField(controller:search,
            onChanged:(_){
              debounce?.cancel();
              debounce=Timer(const Duration(milliseconds:350),refresh);
            },
            decoration:const InputDecoration(
              labelText:'Find by name or username',
              prefixIcon:Icon(Icons.search_outlined))),
          const SizedBox(height:12),
          SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
            for(final item in const {'city':'My city','country':'My country',
              'global':'Worldwide'}.entries)
              Padding(padding:const EdgeInsets.only(right:7),
                child:ChoiceChip(label:Text(item.value),selected:area==item.key,
                  onSelected:(_){setState(()=>area=item.key);unawaited(refresh());})),
          ])),
          if(area=='global'&&search.text.trim().length<2)
            Padding(padding:const EdgeInsets.only(top:9),child:Text(
              'Enter at least 2 characters for worldwide search.',
              style:Theme.of(context).textTheme.bodySmall)),
        ])),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):
        RefreshIndicator(onRefresh:refresh,child:ListView(
          padding:const EdgeInsets.fromLTRB(17,8,17,50),
          children:people.isEmpty?[
            const SizedBox(height:85),
            const Icon(Icons.people_outline,size:55),
            const SizedBox(height:14),
            const Text('No discoverable members match yet',
              textAlign:TextAlign.center),
            const SizedBox(height:9),
            const Text('Try another search or area.',
              textAlign:TextAlign.center),
          ]:people.map(personCard).toList(),
        ))),
    ])));
}

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository.dart';

/// Signed avatar URLs never make the bucket or a private profile public.
/// The small photo is converted locally to JPEG, stripping source metadata.
class ReachAvatar extends StatefulWidget {
  const ReachAvatar({super.key,required this.name,this.path,this.color='indigo',
    this.size=47});
  final String name;
  final String? path;
  final String color;
  final double size;
  static const shades=<String,Color>{
    'indigo':Color(0xFF5857D3),'coral':Color(0xFFEA6D5E),
    'mint':Color(0xFF249E83),'sunset':Color(0xFFD58030),
    'violet':Color(0xFF9953C5),'sky':Color(0xFF198FC2),
    'amber':Color(0xFFBB852D),'rose':Color(0xFFCF4979),
  };
  static final Map<String,({String url,DateTime until})> _cache={};
  static void invalidate(String? path){
    if(path!=null)_cache.remove(path);
  }
  @override State<ReachAvatar> createState()=>_ReachAvatarState();
}
class _ReachAvatarState extends State<ReachAvatar>{
  Future<String?>? url;
  @override void initState(){super.initState();_refresh();}
  @override void didUpdateWidget(covariant ReachAvatar old){
    super.didUpdateWidget(old);
    if(old.path!=widget.path)_refresh();
  }
  void _refresh(){
    final p=widget.path;
    if(p==null||p.isEmpty){url=Future.value(null);return;}
    final stored=ReachAvatar._cache[p];
    if(stored!=null&&stored.until.isAfter(DateTime.now())){
      url=Future.value(stored.url);return;
    }
    url=()async{
      try{
        final link=await Supabase.instance.client.storage
          .from('reach-avatars').createSignedUrl(p,1200);
        ReachAvatar._cache[p]=(url:link,
          until:DateTime.now().add(const Duration(minutes:15)));
        return link;
      }catch(_){return null;}
    }();
  }
  @override Widget build(BuildContext context){
    final c=ReachAvatar.shades[widget.color]??ReachAvatar.shades['indigo']!;
    final initials=widget.name.trim().isEmpty?'?':
      widget.name.trim().split(RegExp(r'\s+'))
        .take(2).map((x)=>x.isEmpty?'':x[0].toUpperCase()).join();
    final placeholder=Container(
      alignment:Alignment.center,
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[c,c.withValues(alpha:.72)],
          begin:Alignment.topLeft,end:Alignment.bottomRight),
        shape:BoxShape.circle),
      child:Text(initials,style:TextStyle(color:Colors.white,
        fontSize:widget.size*.30,fontWeight:FontWeight.w900)));
    return SizedBox(width:widget.size,height:widget.size,
      child:FutureBuilder<String?>(future:url,builder:(context,snap){
        final link=snap.data;
        if(link==null)return placeholder;
        return ClipOval(child:Image.network(link,
          fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>placeholder));
      }));
  }
}

Uint8List _reachCompressAvatar(Uint8List source){
  final decoded=im.decodeImage(source);
  if(decoded==null)throw StateError('Choose a valid JPEG, PNG or WebP image.');
  if(decoded.width>10000||decoded.height>10000){
    throw StateError('This image is too large. Choose another photo.');
  }
  final reduced=im.copyResizeCropSquare(decoded,size:512);
  final out=im.encodeJpg(reduced,quality:80);
  if(out.length>2*1024*1024){
    throw StateError('Could not compress photo below 2 MB.');
  }
  return Uint8List.fromList(out);
}

class ReachAvatarEditor extends StatefulWidget {
  const ReachAvatarEditor({super.key,required this.name,
    this.initialPath,this.initialColor='indigo',
    required this.onSaved});
  final String name;
  final String? initialPath;
  final String initialColor;
  final VoidCallback onSaved;
  @override State<ReachAvatarEditor> createState()=>_ReachAvatarEditorState();
}
class _ReachAvatarEditorState extends State<ReachAvatarEditor>{
  late String? path=widget.initialPath;
  late String color=widget.initialColor;
  bool saving=false;
  void message(Object e){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(e.toString().replaceFirst('Bad state: ','')),
      behavior:SnackBarBehavior.floating));
  }
  Future<void> selectPhoto()async {
    if(saving)return;
    final picked=await FilePicker.pickFiles(type:FileType.image);
    if(picked.isEmpty)return;
    final image=picked.first;
    final filePath=image.path;
    if(filePath==null) {message('This photo cannot be opened.');return;}
    final file=File(filePath);
    final byteSize=await file.length();
    if(byteSize>10*1024*1024){
      message('Choose a photo smaller than 10 MB.');return;
    }
    setState(()=>saving=true);
    try{
      final data=await compute(_reachCompressAvatar,await file.readAsBytes());
      final client=Supabase.instance.client;
      final me=client.auth.currentUser?.id;
      if(me==null)throw StateError('Sign in to upload a photo.');
      final key='$me/avatar.jpg';
      await client.storage.from('reach-avatars').uploadBinary(
        key,data,fileOptions:const FileOptions(
          contentType:'image/jpeg',upsert:true,cacheControl:'30'));
      await ReachRepository(client).updateProfile({'avatar_path':key});
      ReachAvatar.invalidate(key);
      if(mounted){setState(()=>path=key);widget.onSaved();}
    }catch(e){message(e);}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> removePhoto()async{
    if(saving)return;
    setState(()=>saving=true);
    try{
      final client=Supabase.instance.client;
      if(path!=null){
        await client.storage.from('reach-avatars').remove([path!]);
      }
      await ReachRepository(client).updateProfile({'avatar_path':null});
      ReachAvatar.invalidate(path);
      if(mounted){setState(()=>path=null);widget.onSaved();}
    }catch(e){message(e);}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> chooseColor(String next)async{
    if(saving||next==color)return;
    setState(()=>saving=true);
    try{
      await ReachRepository(Supabase.instance.client).updateProfile(
        {'avatar_color':next});
      if(mounted){setState(()=>color=next);widget.onSaved();}
    }catch(e){message(e);}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Column(children:[
    AnimatedSwitcher(
      duration:const Duration(milliseconds:220),
      child:ReachAvatar(key:ValueKey('${path??''}-$color-$saving'),
        name:widget.name,path:path,color:color,size:108)),
    const SizedBox(height:10),
    Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:6,children:[
      OutlinedButton.icon(onPressed:saving?null:selectPhoto,
        icon:const Icon(Icons.photo_camera_outlined),
        label:Text(path==null?'Add photo':'Change photo')),
      if(path!=null)TextButton.icon(onPressed:saving?null:removePhoto,
        icon:const Icon(Icons.delete_outline),label:const Text('Remove')),
    ]),
    if(saving)const Padding(padding:EdgeInsets.all(9),
      child:LinearProgressIndicator()),
    const SizedBox(height:9),
    Wrap(alignment:WrapAlignment.center,spacing:11,runSpacing:11,
      children:[
        for(final entry in ReachAvatar.shades.entries)
          Semantics(button:true,selected:entry.key==color,
            label:'Avatar color ${entry.key}',
            child:InkWell(onTap:saving?null:()=>chooseColor(entry.key),
              customBorder:const CircleBorder(),
              child:AnimatedContainer(
                duration:const Duration(milliseconds:170),
                width:32,height:32,
                decoration:BoxDecoration(color:entry.value,shape:BoxShape.circle,
                  border:Border.all(color:entry.key==color?
                    Theme.of(context).colorScheme.onSurface:Colors.transparent,
                    width:3)),
                child:entry.key==color?
                  const Icon(Icons.check_rounded,color:Colors.white,size:19):null)),
          ),
      ]),
  ]);
}

class ReachMemberProfilePage extends StatefulWidget{
  const ReachMemberProfilePage({super.key,required this.memberId});
  final String memberId;
  @override State<ReachMemberProfilePage> createState()=>_ReachMemberProfilePageState();
}
class _ReachMemberProfilePageState extends State<ReachMemberProfilePage>{
  Map<String,dynamic>? profile;
  String? failure;
  @override void initState(){super.initState();refresh();}
  Future<void> refresh()async{
    try{
      final data=await Supabase.instance.client.rpc('reach_member_profile',
        params:{'p_member':widget.memberId});
      final rows=(data as List).cast<Map<String,dynamic>>();
      if(mounted)setState((){
        profile=rows.isEmpty?null:rows.first;failure=null;
      });
    }catch(e){if(mounted)setState(()=>failure=e.toString());}
  }
  @override Widget build(BuildContext context){
    final p=profile;
    return Scaffold(appBar:AppBar(title:const Text('Member profile')),
      body:SafeArea(child:p==null?Center(child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          Text(failure??'This profile is private or unavailable.'),
          const SizedBox(height:10),
          TextButton(onPressed:refresh,child:const Text('Retry')),
        ])):
      ListView(padding:const EdgeInsets.all(22),children:[
        Center(child:Hero(tag:'reach-member-${widget.memberId}',
          child:ReachAvatar(name:'${p['display_name']}',
            path:p['avatar_path'] as String?,
            color:'${p['avatar_color']}',size:118))),
        const SizedBox(height:14),
        Text('${p['display_name']}',textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.headlineSmall),
        Text('@${p['username']??''}',textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:14),
        Center(child:Chip(avatar:Icon(
          p['profile_visibility']=='public'?Icons.public:Icons.lock_outline,
          size:17),label:Text(p['profile_visibility']=='public'?
            'Public profile':'Private profile'))),
        const SizedBox(height:16),
        if('${p['bio']??''}'.trim().isNotEmpty)...[
          Text('About',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:5),
          Text('${p['bio']}'),
          const SizedBox(height:15),
        ],
        if(p['skills'] is List && (p['skills'] as List).isNotEmpty)...[
          Text('Interests & skills',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:8),
          Wrap(spacing:8,runSpacing:5,children:[
            for(final item in (p['skills'] as List))
              Chip(label:Text('$item')),
          ]),
          const SizedBox(height:11),
        ],
        ListTile(leading:const Icon(Icons.location_city_outlined),
          title:Text('${p['city']}, ${p['country']}')),
      ])));
  }
}

class ReachMemberAvatar extends StatefulWidget{
  const ReachMemberAvatar({super.key,required this.memberId,
    required this.name,this.size=44});
  final String memberId,name;
  final double size;
  @override State<ReachMemberAvatar> createState()=>_ReachMemberAvatarState();
}
class _ReachMemberAvatarState extends State<ReachMemberAvatar>{
  Future<Map<String,dynamic>?>? member;
  @override void initState(){super.initState();refresh();}
  @override void didUpdateWidget(covariant ReachMemberAvatar old){
    super.didUpdateWidget(old);
    if(old.memberId!=widget.memberId)refresh();
  }
  void refresh(){
    member=()async{
      try{
        final rows=await Supabase.instance.client.rpc(
          'reach_member_profile',params:{'p_member':widget.memberId});
        if(rows is! List||rows.isEmpty)return null;
        return Map<String,dynamic>.from(rows.first as Map);
      }catch(_){return null;}
    }();
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>?>(
    future:member,builder:(context,snap){
      final p=snap.data;
      return ReachAvatar(name:widget.name,
        path:p?['avatar_path'] as String?,
        color:p?['avatar_color']?.toString()??'indigo',
        size:widget.size);
    });
}

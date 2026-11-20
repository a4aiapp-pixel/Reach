import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_attachments.dart';
import 'reach_media_prefs.dart';

/// Lightweight, private chat attachment panel that does not request any
/// broad storage permission. The Android system picker grants per-file access.
class ChatAttachmentsPanel extends StatefulWidget {
  const ChatAttachmentsPanel({super.key,required this.conversationId});
  final String conversationId;
  @override State<ChatAttachmentsPanel> createState()=>_ChatAttachmentsPanelState();
}

class _ChatAttachmentsPanelState extends State<ChatAttachmentsPanel> {
  late final ReachAttachments service;
  bool uploading=false;
  int finished=0,total=0;

  @override void initState(){
    super.initState();
    service=ReachAttachments(Supabase.instance.client);
  }

  void notice(Object error){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(error.toString().replaceFirst('Bad state: ',''))));
  }

  Future<void> attach() async {
    if(uploading)return;
    setState((){uploading=true;finished=0;total=0;});
    try{
      final count=await service.pickAndSend(widget.conversationId,
        onProgress:(done,n){
          if(mounted)setState((){finished=done;total=n;});
        });
      if(count>0)notice('$count file(s) shared privately.');
    }catch(e){notice(e);}
    finally{if(mounted)setState(()=>uploading=false);}
  }

  Future<void> openFile(Map<String,dynamic> file)async{
    try{await service.shareFile(file);}
    catch(e){notice(e);}
  }

  Future<void> removeFile(Map<String,dynamic> file)async{
    final own=Supabase.instance.client.auth.currentUser?.id==file['sender_id'];
    if(!own)return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Delete shared file?'),
      content:Text('Remove ${file['file_name']} from the private conversation?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))
      ],
    ));
    if(ok==true){
      try{await service.deleteOwn(file);notice('File deleted.');}
      catch(e){notice(e);}
    }
  }

  Future<void> reportFile(Map<String,dynamic> file) async {
    final reason=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(
      title:const Text('Report unsafe attachment'),
      children:[
        for(final entry in const <String,String>{
          'adult_content':'Pornographic or sexual material',
          'child_safety':'Child safety concern',
          'illegal_content':'Illegal or dangerous material',
          'harassment':'Harassment',
          'fraud':'Fraud or scam',
          'unsafe':'Other unsafe content',
        }.entries)SimpleDialogOption(
          onPressed:()=>Navigator.pop(ctx,entry.key),
          child:Text(entry.value)),
      ]));
    if(reason==null)return;
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null)return;
    try{
      await Supabase.instance.client.from('reports').insert({
        'reporter_id':user.id,'target_type':'attachment',
        'target_id':file['id'],'reason':reason,
        'detail':'User reported this private chat attachment for review.',
      });
      notice('Report submitted. A moderator must review this file.');
    }catch(e){notice(e);}
  }

  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
    decoration:BoxDecoration(
      color:Theme.of(context).colorScheme.surface,
      border:Border(top:BorderSide(color:Theme.of(context).colorScheme.outlineVariant))),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        const Icon(Icons.attach_file_rounded,size:18),
        const SizedBox(width:8),
        Expanded(child:Text('Shared media & files',
          style:Theme.of(context).textTheme.labelLarge)),
        Text('Up to 24 MB',style:Theme.of(context).textTheme.labelSmall),
        IconButton(tooltip:'Auto-download settings',
          onPressed:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>const ReachMediaSettingsPage())),
          icon:const Icon(Icons.tune_outlined)),
        IconButton(
          tooltip:'Share photo, video, audio or document',
          onPressed:uploading?null:attach,
          icon:uploading?
            const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):
            const Icon(Icons.add_circle_outline)),
      ]),
      if(uploading)...[
        LinearProgressIndicator(value:total>0?finished/total:null),
        Padding(padding:const EdgeInsets.only(bottom:4),child:
          Text(total==0?'Selecting files…':'Uploaded $finished of $total files',
            style:Theme.of(context).textTheme.labelSmall)),
      ],
      StreamBuilder<List<Map<String,dynamic>>>(
        stream:service.watch(widget.conversationId),
        builder:(context,snapshot){
          final items=snapshot.data ?? [];
          if(items.isEmpty)return const SizedBox.shrink();
          return SizedBox(height:96,child:ListView.separated(
            scrollDirection:Axis.horizontal,
            itemCount:items.length,
            separatorBuilder:(_,_)=>const SizedBox(width:7),
            itemBuilder:(ctx,index){
              final attachment=items[index];
              return ReachAttachmentPreview(
                key:ValueKey('${attachment['id']}'),
                file:attachment,service:service,
                onTap:()=>openFile(attachment),
                onDelete:()=>removeFile(attachment),
                onReport:()=>reportFile(attachment));
            },
          ));
        },
      ),
    ]),
  );
}

class ReachAttachmentPreview extends StatefulWidget{
  const ReachAttachmentPreview({super.key,required this.file,
    required this.service,required this.onTap,
    required this.onDelete,required this.onReport});
  final Map<String,dynamic> file;
  final ReachAttachments service;
  final VoidCallback onTap,onDelete,onReport;
  @override State<ReachAttachmentPreview> createState()=>
    _ReachAttachmentPreviewState();
}
class _ReachAttachmentPreviewState extends State<ReachAttachmentPreview>{
  File? cached;
  @override void initState(){
    super.initState();
    widget.service.autoDownload(widget.file).then((f){
      if(mounted)setState(()=>cached=f);
    }).catchError((Object error){
      debugPrint('Reach auto-download skipped: $error');
    });
  }
  @override Widget build(BuildContext context){
    final f=widget.file;
    final own=f['sender_id']==Supabase.instance.client.auth.currentUser?.id;
    final mime='${f['mime_type']??''}',size=(f['byte_size'] as num? ?? 0);
    final photo=mime.startsWith('image/');
    final video=mime.startsWith('video/');
    final audio=mime.startsWith('audio/');
    final icon=photo?Icons.image_outlined:video?Icons.videocam_outlined:
      audio?Icons.audiotrack_outlined:Icons.insert_drive_file_outlined;
    return Material(
      color:Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius:BorderRadius.circular(14),clipBehavior:Clip.antiAlias,
      child:InkWell(onTap:widget.onTap,
        onLongPress:own?widget.onDelete:null,
        child:SizedBox(width:200,height:90,
          child:Row(children:[
            SizedBox(width:64,height:90,
              child:photo&&cached!=null
                ?Image.file(cached!,fit:BoxFit.cover,
                   errorBuilder:(_,__,___)=>Icon(icon,size:27))
                :Container(
                  color:Theme.of(context).colorScheme.primaryContainer,
                  child:Icon(icon,size:27,
                    color:Theme.of(context).colorScheme.primary))),
            Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(8,6,1,4),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                mainAxisAlignment:MainAxisAlignment.center,children:[
                Text('${f['file_name']??'Attachment'}',
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  style:Theme.of(context).textTheme.labelMedium),
                const SizedBox(height:4),
                Row(children:[
                  Icon(cached!=null?Icons.check_circle_outline:
                    Icons.download_outlined,size:13),
                  const SizedBox(width:4),
                  Expanded(child:Text(
                    '${(size/1048576).toStringAsFixed(1)} MB',
                    style:Theme.of(context).textTheme.labelSmall,
                    maxLines:1,overflow:TextOverflow.ellipsis)),
                ]),
              ]))),
            PopupMenuButton<String>(
              tooltip:'File options',
              icon:const Icon(Icons.more_vert,size:16),
              onSelected:(value){
                if(value=='delete')widget.onDelete();
                if(value=='report')widget.onReport();
              },
              itemBuilder:(_)=>[
                if(own)const PopupMenuItem(value:'delete',
                  child:Text('Delete')),
                if(!own)const PopupMenuItem(value:'report',
                  child:Text('Report')),
              ]),
          ])),
      ),
    );
  }
}

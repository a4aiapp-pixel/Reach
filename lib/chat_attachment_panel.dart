import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_attachments.dart';

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
        const Icon(Icons.folder_shared_outlined,size:18),
        const SizedBox(width:8),
        Expanded(child:Text('Private chat documents',
          style:Theme.of(context).textTheme.labelLarge)),
        Text('6 MB/file',style:Theme.of(context).textTheme.labelSmall),
        IconButton(
          tooltip:'Share documents (photos/video blocked pending safety screening)',
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
          return SizedBox(height:67,child:ListView.separated(
            scrollDirection:Axis.horizontal,
            itemCount:items.length,
            separatorBuilder:(_,_)=>const SizedBox(width:7),
            itemBuilder:(ctx,index){
              final file=items[index];
              final name=file['file_name'] as String? ?? 'Attachment';
              final own=file['sender_id']==Supabase.instance.client.auth.currentUser?.id;
              final size=file['byte_size'] as num? ?? 0;
              return Material(
                color:Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius:BorderRadius.circular(12),
                child:InkWell(
                  borderRadius:BorderRadius.circular(12),
                  onTap:()=>openFile(file),
                  onLongPress:own?()=>removeFile(file):null,
                  child:ConstrainedBox(
                    constraints:const BoxConstraints(maxWidth:195),
                    child:Padding(
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        const Icon(Icons.insert_drive_file_outlined,size:21),
                        const SizedBox(width:7),
                        Flexible(child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          mainAxisAlignment:MainAxisAlignment.center,
                          children:[
                            Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
                              style:Theme.of(context).textTheme.labelMedium),
                            Text('${(size/1024).toStringAsFixed(0)} KB · ${own?'Sent':'Received'}',
                              maxLines:1,style:Theme.of(context).textTheme.labelSmall)
                          ],
                        )),
                        PopupMenuButton<String>(
                          tooltip:'Attachment actions',
                          icon:const Icon(Icons.more_vert,size:17),
                          onSelected:(v){
                            if(v=='delete')removeFile(file);
                            if(v=='report')reportFile(file);
                          },
                          itemBuilder:(_)=>[
                            if(own)const PopupMenuItem(value:'delete',child:Text('Delete file')),
                            if(!own)const PopupMenuItem(value:'report',child:Text('Report unsafe file')),
                          ]),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ));
        },
      ),
    ]),
  );
}

import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A deliberately small, strictly private attachment transport for an
/// already-approved 1:1 chat. No public URLs, arbitrary executable files,
/// external storage permissions, or unbounded uploads.
/// Media sharing stays off until a real safety scanner/review pipeline exists.
class ReachAttachments {
  ReachAttachments(this.client);
  final SupabaseClient client;
  static const bucket = 'reach-chat';
  static const maxBytes = 6 * 1024 * 1024;
  static const extensions = <String>[
    'pdf','txt','csv','doc','docx','xls','xlsx','ppt','pptx'
  ];

  static String mimeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const types = <String,String>{
      'pdf':'application/pdf', 'txt':'text/plain', 'csv':'text/csv',
      'doc':'application/msword',
      'docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls':'application/vnd.ms-excel',
      'xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt':'application/vnd.ms-powerpoint',
      'pptx':'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png',
      'webp':'image/webp','gif':'image/gif',
      'mp3':'audio/mpeg','m4a':'audio/mp4','aac':'audio/aac',
      'ogg':'audio/ogg','wav':'audio/wav',
      'mp4':'video/mp4','mov':'video/quicktime','webm':'video/webm',
    };
    return types[ext] ?? '';
  }

  static String cleanFilename(String value) {
    final name=value.replaceAll(RegExp(r'[/\\]'),'_').trim();
    if(name.isEmpty)throw ArgumentError('Invalid file name.');
    final lastDot=name.lastIndexOf('.');
    if(lastDot<1)throw ArgumentError('This file type is not supported.');
    final extension=name.substring(lastDot).toLowerCase();
    final stem=name.substring(0,lastDot);
    final allowedStem=stem.substring(0,min(stem.length,180-extension.length));
    final result='$allowedStem$extension';
    if(result.isEmpty||mimeFor(result).isEmpty){
      throw ArgumentError('This file type is not supported.');
    }
    return result;
  }

  String _randomHex() {
    final rng=Random.secure();
    return List<int>.generate(16,(_)=>rng.nextInt(256))
      .map((v)=>v.toRadixString(16).padLeft(2,'0')).join();
  }

  String _safeObjectName(String filename) {
    final sanitized=filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'),'_');
    return sanitized.substring(0,min(sanitized.length,120));
  }

  Stream<List<Map<String,dynamic>>> watch(String conversationId) =>
    client.from('chat_attachments').stream(primaryKey:['id'])
      .eq('conversation_id',conversationId).order('created_at',ascending:false)
      .map((rows)=>rows.where((row)=>row['status']=='ready')
        .map((row)=>Map<String,dynamic>.from(row)).take(40).toList());

  Future<int> pickAndSend(String conversationId,
      {void Function(int done,int total)? onProgress}) async {
    final files=await FilePicker.pickFiles(type:FileType.custom,
      allowedExtensions:extensions);
    if(files.isEmpty)return 0;
    // Deliberately limit batch size to prevent accidental quota exhaustion.
    if(files.length>10)throw StateError('Choose up to 10 files at once.');
    var completed=0;
    for(final picked in files) {
      final filename=cleanFilename(picked.name);
      final size=picked.lengthSync() ?? await picked.length();
      if(size==null||size<1||size>maxBytes){
        throw StateError('Each attachment must be between 1 byte and 6 MB.');
      }
      final path=picked.path;
      if(path==null||path.isEmpty) {
        throw StateError('This file cannot be read. Try selecting it again.');
      }
      final mime=mimeFor(filename);
      final sender=client.auth.currentUser?.id;
      if(sender==null)throw StateError('Sign in to share files.');
      final objectPath='$conversationId/$sender/${_randomHex()}/${_safeObjectName(filename)}';
      String? createdId;
      try {
        final inserted=await client.from('chat_attachments').insert({
          'conversation_id':conversationId,'sender_id':sender,
          'object_path':objectPath,'file_name':filename,'mime_type':mime,
          'byte_size':size,'status':'pending',
        }).select('id').single();
        createdId=inserted['id'] as String;
        await client.storage.from(bucket).upload(objectPath,File(path),
          fileOptions:FileOptions(contentType:mime,upsert:false,cacheControl:'0'));
        await client.from('chat_attachments').update({'status':'ready'})
          .eq('id',createdId);
        completed++;
        onProgress?.call(completed,files.length);
      } catch (_) {
        // Always try to remove partial uploads and release reserved quota.
        try {await client.storage.from(bucket).remove([objectPath]);}catch (_) {}
        if(createdId!=null){
          try {await client.from('chat_attachments').delete().eq('id',createdId);}
          catch (_) {}
        }
        rethrow;
      }
    }
    return completed;
  }

  Future<void> shareFile(Map<String,dynamic> attachment) async {
    final path=attachment['object_path'] as String;
    final filename=cleanFilename(attachment['file_name'] as String);
    final bytes=await client.storage.from(bucket).download(path);
    if(bytes.length>maxBytes)throw StateError('Attachment exceeds allowed size.');
    await SharePlus.instance.share(ShareParams(
      files:[XFile.fromData(bytes,mimeType:mimeFor(filename))],
      fileNameOverrides:[filename],
      subject:filename,
    ));
  }

  Future<void> deleteOwn(Map<String,dynamic> attachment) async {
    if(attachment['sender_id']!=client.auth.currentUser?.id){
      throw StateError('Only the sender can delete this attachment.');
    }
    final path=attachment['object_path'] as String;
    await client.storage.from(bucket).remove([path]);
    await client.from('chat_attachments').delete()
      .eq('id',attachment['id'] as String);
  }
}

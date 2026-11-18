import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reach Assist only receives the text explicitly submitted in this panel.
/// Conversations stay in memory; they are not saved to a user profile or
/// forwarded to any other Reach member or their private chats.
class ReachAssistPage extends StatefulWidget {
  const ReachAssistPage({super.key});
  @override State<ReachAssistPage> createState()=>_ReachAssistPageState();
}

class _ReachAssistMessage {
  const _ReachAssistMessage(this.role,this.text);
  final String role,text;
}

class _ReachAssistPageState extends State<ReachAssistPage> {
  final prompt=TextEditingController();
  final scroll=ScrollController();
  final history=<_ReachAssistMessage>[];
  bool responding=false;
  String mode='chat';
  String? errorText;
  static const modes=<String,String>{
    'chat':'Ask anything',
    'draft':'Draft a Reach post',
    'translate':'Translate',
    'safety':'Check safety',
    'ideas':'Explore ideas',
  };
  static const hints=<String,List<String>>{
    'chat':[
      'How do I ask my community for help?',
      'Help me explain a problem clearly',
      'What makes a good Reach introduction?',
    ],
    'draft':[
      'Write a friendly request for help with home repairs',
      'Draft a post offering Excel tutoring',
      'Help me make this request shorter',
    ],
    'translate':[
      'Translate this message to Urdu',
      'Translate this message to English',
      'Explain this sentence in simple language',
    ],
    'safety':[
      'How can I identify a fake account?',
      'How do I arrange a safe public meetup?',
      'What should I avoid sharing with strangers?',
    ],
    'ideas':[
      'Suggest ways to help neighbors',
      'Give low-cost community project ideas',
      'How can people exchange skills safely?',
    ],
  };
  @override void dispose(){prompt.dispose();scroll.dispose();super.dispose();}

  void showFeedback(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(message)));
  }

  void moveDown(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(scroll.hasClients){
        scroll.animateTo(scroll.position.maxScrollExtent,
          duration:const Duration(milliseconds:240),
          curve:Curves.easeOutCubic);
      }
    });
  }

  Future<void> submit()async{
    if(responding)return;
    final message=prompt.text.trim();
    if(message.isEmpty)return;
    if(message.length>1800){
      showFeedback('Limit your message to 1,800 characters.');
      return;
    }
    final previous=history.reversed.take(6).toList().reversed
      .map((m)=><String,String>{
        'role':m.role,'content':m.text.length>650?m.text.substring(0,650):m.text,
      }).toList();
    setState((){
      history.add(_ReachAssistMessage('user',message));
      responding=true;errorText=null;prompt.clear();
    });
    moveDown();
    try{
      final response=await Supabase.instance.client.functions.invoke('reach-assist',
        body:<String,dynamic>{
          'message':message,'mode':mode,'history':previous,
        });
      final data=response.data;
      if(data is! Map || data['answer'] is! String){
        throw StateError('Reach Assist is temporarily unavailable. Try later.');
      }
      if(mounted){
        setState((){history.add(_ReachAssistMessage('assistant',data['answer'] as String));});
        moveDown();
      }
    }catch(e){
      if(mounted){
        setState((){
          errorText='Reach Assist could not answer. Your message was not shared '
            'with other Reach members. You can retry.';
        });
      }
    }finally{
      if(mounted)setState(()=>responding=false);
    }
  }

  Widget _bubble(_ReachAssistMessage value){
    final mine=value.role=='user';
    final scheme=Theme.of(context).colorScheme;
    return Align(
      alignment:mine?Alignment.centerRight:Alignment.centerLeft,
      child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.87),
        child:Padding(
          padding:const EdgeInsets.symmetric(vertical:6),
          child:Container(
            decoration:BoxDecoration(
              color:mine?scheme.primaryContainer:scheme.surfaceContainerHigh,
              borderRadius:BorderRadius.circular(19)),
            padding:const EdgeInsets.fromLTRB(14,12,12,9),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              if(!mine)Padding(
                padding:const EdgeInsets.only(bottom:7),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(Icons.auto_awesome,color:scheme.primary,size:17),
                  const SizedBox(width:5),
                  Text('Reach Assist · AI',style:Theme.of(context).textTheme.labelMedium),
                ])),
              SelectableText(value.text),
              if(!mine)Row(mainAxisSize:MainAxisSize.min,children:[
                IconButton(
                  visualDensity:VisualDensity.compact,
                  constraints:const BoxConstraints(minWidth:36,minHeight:36),
                  tooltip:'Copy answer',
                  icon:const Icon(Icons.copy_outlined,size:17),
                  onPressed:()async{
                    await Clipboard.setData(ClipboardData(text:value.text));
                    showFeedback('Answer copied. Review before posting.');
                  }),
                IconButton(
                  visualDensity:VisualDensity.compact,
                  constraints:const BoxConstraints(minWidth:36,minHeight:36),
                  tooltip:'Share answer',
                  icon:const Icon(Icons.ios_share_outlined,size:17),
                  onPressed:()=>SharePlus.instance.share(ShareParams(text:value.text)),
                )
              ])
            ]),
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Row(children:[
        Icon(Icons.auto_awesome_outlined),
        SizedBox(width:10),
        Expanded(child:Text('Reach Assist')),
      ]),
      actions:[
        IconButton(tooltip:'Clear private AI conversation',
          icon:const Icon(Icons.delete_sweep_outlined),
          onPressed:history.isEmpty?null:(){
            setState((){
              history.clear();errorText=null;
            });
            showFeedback('Conversation cleared from this screen.');
          }),
      ]),
    body:SafeArea(child:Column(children:[
      Padding(
        padding:const EdgeInsets.fromLTRB(15,7,15,8),
        child:Card(child:Padding(
          padding:const EdgeInsets.all(11),
          child:Row(children:[
            const Icon(Icons.lock_outline,size:20),
            const SizedBox(width:10),
            const Expanded(child:Text(
              'Your private Reach chats and files are not read automatically. '
              'Only the text you submit here goes to the AI provider.',
              style:TextStyle(fontSize:12))),
          ]),
        )),
      ),
      SizedBox(height:47,child:ListView(
        scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.symmetric(horizontal:12),
        children:modes.entries.map((entry)=>Padding(
          padding:const EdgeInsets.only(right:7),
          child:ChoiceChip(
            label:Text(entry.value),
            avatar:mode==entry.key?const Icon(Icons.check,size:15):null,
            selected:mode==entry.key,
            onSelected:responding?null:(_){
              setState(()=>mode=entry.key);
            },
          ),
        )).toList(),
      )),
      Expanded(child:ListView(
        controller:scroll,
        padding:const EdgeInsets.fromLTRB(15,10,15,24),
        children:[
          if(history.isEmpty)...[
            const SizedBox(height:28),
            Center(child:Icon(Icons.auto_awesome,
              size:54,color:Theme.of(context).colorScheme.primary)),
            const SizedBox(height:12),
            Text('What can I help you with?',
              textAlign:TextAlign.center,
              style:Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height:7),
            const Text('Draft better requests, translate, brainstorm, or '
              'get guidance about staying safe online.',
              textAlign:TextAlign.center),
            const SizedBox(height:18),
            for(final example in hints[mode]??const <String>[])
              Card(child:ListTile(
                title:Text(example),
                trailing:const Icon(Icons.arrow_outward,size:17),
                onTap:()=>setState(()=>prompt.text=example))),
          ],
          for(final msg in history)_bubble(msg),
          if(responding)Padding(
            padding:const EdgeInsets.symmetric(vertical:12),
            child:Row(children:[
              const SizedBox(width:12,height:12,
                child:CircularProgressIndicator(strokeWidth:2)),
              const SizedBox(width:10),
              Text('Preparing an AI response…',
                style:Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          if(errorText!=null)Card(
            child:Padding(
              padding:const EdgeInsets.all(12),
              child:Row(children:[
                const Icon(Icons.info_outline),
                const SizedBox(width:10),
                Expanded(child:Text(errorText!)),
              ]),
            )),
        ],
      )),
      Container(
        decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,
          border:Border(top:BorderSide(
            color:Theme.of(context).colorScheme.outlineVariant))),
        padding:const EdgeInsets.fromLTRB(10,8,9,4),
        child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Expanded(child:TextField(
            controller:prompt,
            maxLength:1800,minLines:1,maxLines:4,
            textCapitalization:TextCapitalization.sentences,
            textInputAction:TextInputAction.newline,
            decoration:const InputDecoration(
              hintText:'Ask Reach Assist…',
              counterText:'',prefixIcon:Icon(Icons.chat_bubble_outline)),
          )),
          const SizedBox(width:5),
          IconButton.filled(
            tooltip:'Send to Reach AI provider',
            onPressed:responding?null:submit,
            icon:const Icon(Icons.arrow_upward)),
        ]),
      ),
      Padding(
        padding:const EdgeInsets.fromLTRB(12,0,12,9),
        child:Text(
          'AI can be inaccurate. Verify important information; nothing is posted automatically.',
          textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ])),
  );
}

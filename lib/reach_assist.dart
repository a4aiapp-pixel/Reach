import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'reach_local_assist.dart';

/// Reach Assist only receives the text explicitly submitted in this panel.
/// Conversations stay in memory; they are not saved to a user profile or
/// forwarded to any other Reach member or their private chats.
class ReachAssistPage extends StatefulWidget {
  const ReachAssistPage({super.key});
  @override State<ReachAssistPage> createState()=>_ReachAssistPageState();
}

class _ReachAssistMessage {
  const _ReachAssistMessage(this.role,this.text,{this.source='local'});
  final String role,text,source;
}

class _ReachAssistPageState extends State<ReachAssistPage> {
  final prompt=TextEditingController();
  final scroll=ScrollController();
  final history=<_ReachAssistMessage>[];
  bool responding=false;
  bool cloudMode=false,cloudConsent=false;
  String mode='chat';
  String? errorText;
  static const modes=ReachLocalAssist.modes;
  static const hints=<String,List<String>>{
    'chat':[
      'How do I ask my community for help?',
      'How can I avoid a fake account?',
      'How do I share a helpful introduction?',
    ],
    'polish':[
      'pls help me with excel i dont understand it',
      'hi i can teach math pls msg me',
      'im available tomorrow if u need help',
    ],
    'draft':[
      'Write a friendly request for help with home repairs',
      'Draft a post offering Excel tutoring',
      'Help me make this request shorter',
    ],
    'translate':[
      'Show common Reach phrases in English and Urdu',
      'How do I say thank you in Urdu?',
      'What is an offline phrasebook?',
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

  Future<void> submit()async {
    if(responding)return;
    final message=prompt.text.trim();
    if(message.isEmpty)return;
    if(message.length>1800) {
      showFeedback('Limit your message to 1,800 characters.');
      return;
    }
    if(cloudMode&&!cloudConsent){
      showFeedback('Please agree to send this message to the cloud AI provider.');
      return;
    }
    final previous=history.reversed.take(6).toList().reversed
      .map((m)=><String,String>{
        'role':m.role,
        'content':m.text.length>650?m.text.substring(0,650):m.text,
      }).toList();
    setState((){
      history.add(_ReachAssistMessage('user',message));
      responding=true;
      errorText=null;
      prompt.clear();
    });
    moveDown();
    if(!cloudMode) {
      // Always usable, no internet access, model charges, tokens or user data
      // sent to any AI provider.
      final answer=ReachLocalAssist.respond(mode,message);
      if(mounted){
        setState((){
          history.add(_ReachAssistMessage('assistant',answer));
          responding=false;
        });
        moveDown();
      }
      return;
    }
    try{
      // Cloud mode requires an explicit build-time flag AND opt-in on every
      // message. The backend itself rejects requests without provider secrets.
      if(!AppConfig.aiEnabled)throw StateError('Cloud AI is disabled.');
      final response=await Supabase.instance.client.functions.invoke('reach-assist',
        body:<String,dynamic>{'message':message,'mode':mode,'history':previous});
      final data=response.data;
      if(data is! Map || data['answer'] is! String){
        throw StateError('Cloud AI unavailable.');
      }
      if(mounted){
        setState((){
          history.add(_ReachAssistMessage('assistant',
            data['answer'] as String,source:'cloud'));
          cloudConsent=false;
        });
        moveDown();
      }
    }catch(_){
      // Cloud failures never block a free local response.
      if(mounted){
        setState((){
          history.add(_ReachAssistMessage('assistant',
            ReachLocalAssist.respond(mode,message)));
          errorText='Cloud AI is unavailable. Local smart tools answered instead. '
            'No payment was requested.';
          cloudMode=false;
          cloudConsent=false;
        });
        moveDown();
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
                  Text(value.source=='cloud'?'Reach Assist · Cloud AI':'Reach Assist · Local tools',
                    style:Theme.of(context).textTheme.labelMedium),
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
        IconButton(tooltip:'Clear assistant conversation',
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
              'Free local tools work offline: your text stays on this device. '
              'No private chats or files are read automatically.',
              style:TextStyle(fontSize:12))),
          ]),
        )),
      ),
      if(AppConfig.aiEnabled)Padding(
        padding:const EdgeInsets.symmetric(horizontal:15,vertical:4),
        child:Column(children:[
          SwitchListTile.adaptive(
            contentPadding:EdgeInsets.zero,
            title:const Text('Optional cloud AI'),
            subtitle:const Text('Off by default. Local tools remain free.'),
            value:cloudMode,
            onChanged:(v)=>setState((){
              cloudMode=v;
              cloudConsent=false;
            })),
          if(cloudMode)CheckboxListTile(
            contentPadding:EdgeInsets.zero,
            title:const Text('Send only this message and up to six recent '
              'assistant turns to the configured AI provider'),
            subtitle:const Text('Do not include passwords, IDs or private chats.'),
            value:cloudConsent,
            onChanged:(v)=>setState(()=>cloudConsent=v??false)),
        ]),
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
            const Text('Draft posts, polish writing, browse everyday '
              'English–Urdu phrases, explore ideas and spot common risk patterns.',
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
              Text(cloudMode?'Contacting optional cloud AI…':'Preparing local response…',
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
            tooltip:cloudMode?'Send to optional cloud AI':'Run free local smart tool',
            onPressed:responding?null:submit,
            icon:const Icon(Icons.arrow_upward)),
        ]),
      ),
      Padding(
        padding:const EdgeInsets.fromLTRB(12,0,12,9),
        child:Text(
          cloudMode
            ? 'Cloud AI can be inaccurate. Review results; no automatic posting.'
            : 'Offline rule-based tools, not generative AI. Review results; nothing is posted.',
          textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ])),
  );
}

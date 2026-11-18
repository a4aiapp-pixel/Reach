import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Foreground-only calling. Disabled in production unless ENABLE_REACH_CALLS
/// is explicitly set by the release operator after two-device acceptance tests.
/// Privacy: camera and microphone are NEVER opened until callee accepts.
class ReachCalls {
  ReachCalls(this.client);
  final SupabaseClient client;

  static bool isTerminal(String status) =>
    const {'declined','cancelled','ended','missed'}.contains(status);

  Future<Map<String,dynamic>> start(String conversation,String kind) async {
    final raw=await client.rpc('start_reach_call',
      params:{'p_conversation':conversation,'p_kind':kind});
    return Map<String,dynamic>.from(raw as Map);
  }

  Future<Map<String,dynamic>> respond(String id,String action) async {
    final raw=await client.rpc('answer_reach_call',
      params:{'p_call':id,'p_action':action});
    return Map<String,dynamic>.from(raw as Map);
  }

  Stream<List<Map<String,dynamic>>> calls(String conversation) =>
    client.from('reach_calls').stream(primaryKey:['id'])
      .eq('conversation_id',conversation).order('created_at',ascending:false)
      .limit(15).map((rows)=>rows.map((r)=>Map<String,dynamic>.from(r)).toList());

  Stream<List<Map<String,dynamic>>> call(String id) =>
    client.from('reach_calls').stream(primaryKey:['id']).eq('id',id)
      .map((rows)=>rows.map((r)=>Map<String,dynamic>.from(r)).toList());

  Stream<List<Map<String,dynamic>>> signals(String id) =>
    client.from('reach_call_signals').stream(primaryKey:['id'])
      .eq('call_id',id).order('id')
      .map((rows)=>rows.map((r)=>Map<String,dynamic>.from(r)).toList());

  Future<void> signal(String callId,String peerId,String type,Map<String,dynamic> value) async {
    final sender=client.auth.currentUser?.id;
    if(sender==null)throw StateError('Sign in before calling');
    await client.from('reach_call_signals').insert({
      'call_id':callId,'sender_id':sender,'receiver_id':peerId,
      'signal_type':type,'payload':value,
    });
  }
}

class ReachCallActions extends StatefulWidget {
  const ReachCallActions({super.key,required this.conversationId,
    required this.peerId,required this.peerName});
  final String conversationId,peerId,peerName;
  @override State<ReachCallActions> createState()=>_ReachCallActionsState();
}
class _ReachCallActionsState extends State<ReachCallActions> {
  late final ReachCalls calls;
  late final Stream<List<Map<String,dynamic>>> updates;
  bool starting=false;
  @override void initState(){
    super.initState();
    calls=ReachCalls(Supabase.instance.client);
    updates=calls.calls(widget.conversationId);
  }
  void alert(Object error){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(error.toString().replaceFirst('PostgrestException(message: ',''))));
  }
  Future<void> dial(bool video) async {
    if(starting)return;
    setState(()=>starting=true);
    try{
      final value=await calls.start(widget.conversationId,video?'video':'audio');
      if(mounted)await Navigator.push<void>(context,MaterialPageRoute(
        builder:(_)=>ReachCallScreen(
          call:value,peerName:widget.peerName,caller:true)));
    }catch(e){alert(e);}
    finally{if(mounted)setState(()=>starting=false);}
  }
  Future<void> incoming(Map<String,dynamic> call)async{
    await Navigator.push<void>(context,MaterialPageRoute(
      builder:(_)=>ReachCallScreen(call:call,
        peerName:widget.peerName,caller:false)));
  }
  Future<void> decline(Map<String,dynamic> call)async{
    try{await calls.respond(call['id'] as String,'decline');}
    catch(e){alert(e);}
  }
  @override Widget build(BuildContext context)=>StreamBuilder<List<Map<String,dynamic>>>(
    stream:updates,
    builder:(context,snapshot){
      final current=Supabase.instance.client.auth.currentUser?.id;
      final rows=snapshot.data??[];
      final ringing=rows.where((r)=>r['status']=='ringing'&&r['callee_id']==current
        &&DateTime.tryParse(r['expires_at'] as String? ?? '')?.isAfter(DateTime.now())==true);
      final incomingCall=ringing.isEmpty?null:ringing.first;
      return Column(mainAxisSize:MainAxisSize.min,children:[
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          TextButton.icon(
            onPressed:starting?null:()=>dial(false),
            icon:const Icon(Icons.call_outlined),
            label:const Text('Voice call')),
          const SizedBox(width:7),
          TextButton.icon(
            onPressed:starting?null:()=>dial(true),
            icon:const Icon(Icons.videocam_outlined),
            label:const Text('Video call')),
          if(starting)const SizedBox(width:18,height:18,
            child:CircularProgressIndicator(strokeWidth:2)),
        ]),
        if(incomingCall!=null)Card(
          child:Padding(padding:const EdgeInsets.all(12),
            child:Row(children:[
              Icon(incomingCall['kind']=='video'?Icons.videocam:Icons.call,
                color:Theme.of(context).colorScheme.primary),
              const SizedBox(width:8),
              Expanded(child:Text(
                'Incoming ${incomingCall['kind']} call from ${widget.peerName}',
                maxLines:2)),
              IconButton(tooltip:'Decline',onPressed:()=>decline(incomingCall),
                icon:const Icon(Icons.call_end,color:Colors.red)),
              IconButton(tooltip:'Answer',onPressed:()=>incoming(incomingCall),
                icon:const Icon(Icons.call,color:Colors.green)),
            ])),
        ),
      ]);
    },
  );
}

class ReachCallScreen extends StatefulWidget {
  const ReachCallScreen({super.key,required this.call,required this.peerName,
    required this.caller});
  final Map<String,dynamic> call;
  final String peerName;
  final bool caller;
  @override State<ReachCallScreen> createState()=>_ReachCallScreenState();
}
class _ReachCallScreenState extends State<ReachCallScreen>
    with WidgetsBindingObserver {
  late final ReachCalls service;
  late final String callId,peerId;
  late final bool video;
  final RTCVideoRenderer local=RTCVideoRenderer();
  final RTCVideoRenderer remote=RTCVideoRenderer();
  StreamSubscription<List<Map<String,dynamic>>>? watchCall,watchSignals;
  RTCPeerConnection? pc;
  MediaStream? media;
  Timer? ringTimer;
  Timer? connectionTimer;
  final List<RTCIceCandidate> pendingCandidates=[];
  int lastSignal=0;
  bool prepared=false,starting=false,offered=false,answered=false;
  bool muted=false,cameraOff=false,speaker=false,finished=false;
  bool rendererReady=false,connectionEstablished=false;
  String state='Preparing…';

  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service=ReachCalls(Supabase.instance.client);
    callId=widget.call['id'] as String;
    peerId=widget.caller?
      widget.call['callee_id'] as String:widget.call['caller_id'] as String;
    video=widget.call['kind']=='video';
    state=widget.caller?'Ringing…':'Incoming call';
    unawaited(_initialize());
  }

  Future<void> _initialize()async {
    try{
      await local.initialize();
      await remote.initialize();
      rendererReady=true;
      if(!mounted||finished)return;
      watchCall=service.call(callId).listen(_callUpdated,
        onError:(Object e)=>_fail('Call updates unavailable'));
      ringTimer=Timer(const Duration(seconds:47),(){
        if(!finished&&!prepared){
          if(widget.caller)unawaited(_end('cancel'));
          else _fail('Missed call');
        }
      });
      if(mounted)setState((){});
    }catch(_){_fail('Could not initialize camera or audio engine');}
  }

  void _callUpdated(List<Map<String,dynamic>> values){
    if(finished||values.isEmpty)return;
    final item=values.first;
    final status=item['status'] as String? ?? '';
    if(ReachCalls.isTerminal(status)){
      _finish('Call $status');
      return;
    }
    if(status=='accepted'&&!starting){
      starting=true;
      ringTimer?.cancel();
      unawaited(_prepareMedia());
    }
  }

  Future<void> accept()async {
    try{
      final result=await service.respond(callId,'accept');
      if(result['status']!='accepted')throw StateError('Call expired');
      // Let watchCall start the connection on both devices.
      if(!starting){starting=true;ringTimer?.cancel();await _prepareMedia();}
    }catch(e){_fail('Could not answer this call: $e');}
  }

  Future<void> decline()async{
    try{await service.respond(callId,'decline');}catch(_){}
    _finish('Declined');
  }

  Future<void> _prepareMedia()async {
    if(finished||prepared)return;
    try{
      // This is the first point microphone/camera permission is requested.
      media=await navigator.mediaDevices.getUserMedia({
        'audio':true,
        'video':video?{'facingMode':'user'}:false,
      });
      if(finished){for(final t in media!.getTracks()){t.stop();}return;}
      local.srcObject=media;
      // STUN-only test path. NATs needing TURN are explicitly unsupported
      // until a real paid/funded TURN provider with short-lived creds exists.
      pc=await createPeerConnection({
        'iceServers':[{'urls':'stun:stun.l.google.com:19302'}],
        'sdpSemantics':'unified-plan'
      });
      pc!.onTrack=(event){
        if(event.streams.isNotEmpty){
          remote.srcObject=event.streams.first;
          if(mounted)setState((){});
        }
      };
      pc!.onIceCandidate=(candidate){
        if(!finished&&candidate.candidate!=null){
          unawaited(service.signal(callId,peerId,'candidate',{
            'candidate':candidate.candidate,
            'sdpMid':candidate.sdpMid,
            'sdpMLineIndex':candidate.sdpMLineIndex,
          }).catchError((Object _){_fail('Network negotiation failed');}));
        }
      };
      pc!.onConnectionState=(value){
        if(finished||!mounted)return;
        setState((){
          if(value==RTCPeerConnectionState.RTCPeerConnectionStateConnected){
            connectionEstablished=true;
            state='Connected';connectionTimer?.cancel();
          }else if(value==RTCPeerConnectionState.RTCPeerConnectionStateDisconnected){
            state='Reconnecting…';
          }else if(value==RTCPeerConnectionState.RTCPeerConnectionStateFailed){
            state='Connection failed — try another network';
          }
        });
        if(value==RTCPeerConnectionState.RTCPeerConnectionStateFailed){
          unawaited(_end('end'));
        }
      };
      for(final track in media!.getTracks()){await pc!.addTrack(track,media!);}
      prepared=true;
      if(mounted)setState(()=>state='Connecting…');
      watchSignals=service.signals(callId).listen(
        (rows)=>unawaited(_processSignals(rows)),
        onError:(Object _)=>_fail('Call signaling disconnected'));
      connectionTimer=Timer(const Duration(seconds:35),(){
        if(!finished&&!connectionEstablished)unawaited(_end('end'));
      });
      if(widget.caller){
        final offer=await pc!.createOffer();
        await pc!.setLocalDescription(offer);
        offered=true;
        await service.signal(callId,peerId,'offer',{
          'sdp':offer.sdp,'type':offer.type
        });
      }
    }catch(_){_fail('Unable to start media. Check permissions and connectivity.');}
  }

  Future<void> _processSignals(List<Map<String,dynamic>> rows)async {
    if(finished||pc==null)return;
    for(final row in rows){
      final id=(row['id'] as num).toInt();
      if(id<=lastSignal)continue;
      lastSignal=id;
      if(row['sender_id']==Supabase.instance.client.auth.currentUser?.id)continue;
      final kind=row['signal_type'] as String;
      final payload=Map<String,dynamic>.from(row['payload'] as Map);
      try{
        if(kind=='offer'&&!widget.caller&&!answered){
          final sdp=payload['sdp'] as String?;
          if(sdp==null)continue;
          await pc!.setRemoteDescription(RTCSessionDescription(sdp,'offer'));
          await _flushCandidates();
          final response=await pc!.createAnswer();
          await pc!.setLocalDescription(response);
          answered=true;
          await service.signal(callId,peerId,'answer',{
            'sdp':response.sdp,'type':response.type
          });
        }else if(kind=='answer'&&widget.caller&&offered&&!answered){
          final sdp=payload['sdp'] as String?;
          if(sdp==null)continue;
          await pc!.setRemoteDescription(RTCSessionDescription(sdp,'answer'));
          answered=true;
          await _flushCandidates();
        }else if(kind=='candidate'){
          final candidate=payload['candidate'] as String?;
          if(candidate==null)continue;
          final item=RTCIceCandidate(candidate,payload['sdpMid'] as String?,
            (payload['sdpMLineIndex'] as num?)?.toInt());
          if(await pc!.getRemoteDescription()==null){pendingCandidates.add(item);}
          else{await pc!.addCandidate(item);}
        }
      }catch(_){_fail('Call negotiation failed. Retry the call.');return;}
    }
  }

  Future<void> _flushCandidates()async {
    final candidates=List<RTCIceCandidate>.from(pendingCandidates);
    pendingCandidates.clear();
    for(final candidate in candidates){await pc?.addCandidate(candidate);}
  }

  Future<void> switchCamera()async {
    if(!video||media==null)return;
    final tracks=media!.getVideoTracks();
    if(tracks.isNotEmpty){
      try{await Helper.switchCamera(tracks.first);}
      catch(_){_showError('Cannot switch camera on this device');}
    }
  }

  void _showError(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(message)));
  }

  Future<void> toggleSpeaker()async {
    try{
      await Helper.setSpeakerphoneOn(!speaker);
      if(mounted)setState(()=>speaker=!speaker);
    }catch(_){_showError('Speaker control unavailable');}
  }

  Future<void> _end(String action)async {
    if(finished)return;
    try{await service.respond(callId,action);}
    catch(_){}
    _finish(action=='cancel'?'Cancelled':'Call ended');
  }

  void _fail(String reason){
    if(finished)return;
    _showError(reason);
    if(starting||prepared)unawaited(_end('end'));
    else if(widget.caller)unawaited(_end('cancel'));
    else _finish(reason);
  }

  void _finish(String status){
    if(finished)return;
    finished=true;
    ringTimer?.cancel();connectionTimer?.cancel();
    unawaited(watchCall?.cancel()??Future<void>.value());
    unawaited(watchSignals?.cancel()??Future<void>.value());
    for(final track in media?.getTracks()??<MediaStreamTrack>[]) {track.stop();}
    local.srcObject=null;remote.srcObject=null;
    if(pc!=null)unawaited(pc!.dispose());
    if(media!=null)unawaited(media!.dispose());
    if(rendererReady){
      unawaited(local.dispose());unawaited(remote.dispose());
    }
    if(mounted)setState(()=>state=status);
  }

  @override void didChangeAppLifecycleState(AppLifecycleState next){
    // No background recording, active microphone, or video without a
    // declared Android foreground-service use case.
    if(next==AppLifecycleState.paused&&!finished){
      unawaited(_end(widget.caller&&!prepared?'cancel':'end'));
    }
  }

  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    if(!finished)unawaited(_end(widget.caller&&!prepared?'cancel':'end'));
    super.dispose();
  }

  @override Widget build(BuildContext context){
    final accepted=prepared&&video;
    return PopScope(
      canPop:finished,
      onPopInvokedWithResult:(didPop,_) {
        if(!didPop)unawaited(_end(widget.caller&&!prepared?'cancel':'end'));
      },
      child:Scaffold(
        backgroundColor:Theme.of(context).colorScheme.surface,
        appBar:AppBar(title:Text(video?'Video call':'Voice call'),
          actions:[
            IconButton(tooltip:'End call',onPressed:()=>_end(
              widget.caller&&!prepared?'cancel':'end'),
              icon:const Icon(Icons.call_end,color:Colors.red))
          ]),
        body:SafeArea(child:Column(children:[
          Expanded(child:Stack(fit:StackFit.expand,children:[
            if(accepted)RTCVideoView(remote,objectFit:RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              CircleAvatar(radius:51,child:Icon(
                video?Icons.videocam:Icons.phone,size:49)),
              const SizedBox(height:14),
              Text(widget.peerName,style:Theme.of(context).textTheme.headlineSmall),
            ])),
            if(accepted)Positioned(right:16,top:16,width:112,height:156,
              child:ClipRRect(borderRadius:BorderRadius.circular(16),
                child:RTCVideoView(local,mirror:true,
                  objectFit:RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))),
          ])),
          Text(state,style:Theme.of(context).textTheme.titleMedium),
          if(!widget.caller&&!starting&&!finished)...[
            const Padding(padding:EdgeInsets.all(12),
              child:Text('Microphone and camera access is requested only after you accept.',
                textAlign:TextAlign.center)),
            Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
              FilledButton.tonalIcon(onPressed:decline,
                icon:const Icon(Icons.call_end),label:const Text('Decline')),
              FilledButton.icon(onPressed:accept,
                icon:const Icon(Icons.call),label:const Text('Accept')),
            ]),
          ],
          if(prepared&&!finished)Row(
            mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
              IconButton.filledTonal(
                tooltip:muted?'Unmute':'Mute',onPressed:(){
                  for(final track in media?.getAudioTracks()??<MediaStreamTrack>[]){
                    track.enabled=muted;
                  }
                  setState(()=>muted=!muted);
                },icon:Icon(muted?Icons.mic_off:Icons.mic)),
              IconButton.filledTonal(
                tooltip:speaker?'Earpiece':'Speaker',onPressed:toggleSpeaker,
                icon:Icon(speaker?Icons.volume_up:Icons.hearing)),
              if(video)IconButton.filledTonal(
                tooltip:cameraOff?'Enable camera':'Disable camera',onPressed:(){
                  for(final track in media?.getVideoTracks()??<MediaStreamTrack>[]){
                    track.enabled=cameraOff;
                  }
                  setState(()=>cameraOff=!cameraOff);
                },icon:Icon(cameraOff?Icons.videocam_off:Icons.videocam)),
              if(video)IconButton.filledTonal(
                tooltip:'Flip camera',onPressed:switchCamera,
                icon:const Icon(Icons.flip_camera_android)),
            ]),
          Padding(padding:const EdgeInsets.all(18),
            child:FilledButton.icon(
              onPressed:finished?()=>Navigator.pop(context):
                ()=>_end(widget.caller&&!prepared?'cancel':'end'),
              icon:Icon(finished?Icons.close:Icons.call_end),
              label:Text(finished?'Close':'End call')),
          ),
        ])),
      ),
    );
  }
}

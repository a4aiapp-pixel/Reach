import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repository.dart';

/// Privacy and communication consent controls. On slow networks the switch
/// changes immediately but is visibly pending until the server confirms it.
/// A failed write rolls back; turning consent ON is never queued silently.
class ReachPrivacyPreferences extends StatefulWidget {
  const ReachPrivacyPreferences({
    super.key,required this.profile,required this.onChanged,
    required this.callingEnabled,required this.pushEnabled,
  });
  final Map<String,dynamic> profile;
  final VoidCallback onChanged;
  final bool callingEnabled,pushEnabled;

  @override State<ReachPrivacyPreferences> createState()=>_ReachPrivacyPreferencesState();
}

class _ReachPrivacyPreferencesState extends State<ReachPrivacyPreferences> {
  late Map<String,dynamic> values;
  late final ReachRepository repository=ReachRepository(Supabase.instance.client);
  String? savingKey,errorMessage,retryKey;
  dynamic retryValue;

  @override void initState(){
    super.initState();
    values=Map<String,dynamic>.from(widget.profile);
  }

  @override void didUpdateWidget(covariant ReachPrivacyPreferences oldWidget){
    super.didUpdateWidget(oldWidget);
    if(!identical(widget.profile,oldWidget.profile)&&savingKey==null){
      values=Map<String,dynamic>.from(widget.profile);
    }
  }

  String _readableError(Object error){
    if(error is TimeoutException)return 'Could not confirm the change. Check your connection and retry.';
    if(error is PostgrestException){
      return error.message.isEmpty?'Could not save the preference.':error.message;
    }
    final value=error.toString();
    final lower=value.toLowerCase();
    if(lower.contains('socketexception')||lower.contains('clientexception')||
       lower.contains('connection timed out')||lower.contains('failed host lookup')||
       lower.contains('handshakeexception')||lower.contains('network is unreachable')){
      return 'Reach could not connect to its server. Try Wi-Fi or mobile data and retry.';
    }
    return value.replaceFirst('Bad state: ','').replaceFirst('Exception: ','');
  }

  Future<void> _save(String key,dynamic next,Future<void> Function() operation) async {
    if(savingKey!=null || values[key]==next)return;
    final before=values[key];
    setState((){
      values[key]=next;
      savingKey=key;
      errorMessage=null;
      retryKey=null;
      retryValue=null;
    });
    try{
      // A server response must confirm that a matching row was UPDATED.
      // Timeout does not cancel an in-flight write, so never claim success.
      await operation().timeout(const Duration(seconds:22));
      if(!mounted)return;
      setState(()=>savingKey=null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Privacy preference saved.'),
        duration:Duration(seconds:2)));
      widget.onChanged();
    }catch(e){
      if(!mounted)return;
      setState((){
        values[key]=before;
        savingKey=null;
        errorMessage=_readableError(e);
        retryKey=key;
        retryValue=next;
      });
    }
  }

  Future<void> _update(String key,dynamic value) =>
    _save(key,value,()=>repository.updateProfile({key:value}));

  Future<void> _nearby(bool enabled)=>_save('location_opt_in',enabled,()async{
    if(enabled){
      await repository.setApproxLocation();
      try{
        await repository.updateProfile({'location_opt_in':true});
      }catch(e){
        try{await repository.forgetLocation();}catch(_){}
        rethrow;
      }
    }else{
      await repository.forgetLocation();
      await repository.updateProfile({'location_opt_in':false});
    }
  });

  Future<void> _retry() async{
    final key=retryKey,next=retryValue;
    if(key==null)return;
    if(key=='location_opt_in')await _nearby(next==true);
    else await _update(key,next);
  }

  Widget _icon(String key,IconData icon){
    if(savingKey==key)return const SizedBox(width:22,height:22,
      child:CircularProgressIndicator(strokeWidth:2));
    return Icon(icon);
  }

  @override Widget build(BuildContext context)=>Card(child:Column(children:[
    if(savingKey!=null)Padding(
      padding:const EdgeInsets.fromLTRB(16,14,16,10),
      child:Row(children:[
        const SizedBox(width:18,height:18,
          child:CircularProgressIndicator(strokeWidth:2)),
        const SizedBox(width:12),
        Expanded(child:Text('Saving securely…',
          style:Theme.of(context).textTheme.bodySmall)),
      ])),
    if(errorMessage!=null)Padding(
      padding:const EdgeInsets.fromLTRB(16,14,12,8),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(Icons.wifi_off_outlined,
            color:Theme.of(context).colorScheme.error,size:20),
          const SizedBox(width:9),
          Expanded(child:Text(errorMessage!,
            style:TextStyle(color:Theme.of(context).colorScheme.error))),
        ]),
        Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          TextButton.icon(onPressed:savingKey==null?widget.onChanged:null,
            icon:const Icon(Icons.sync,size:18),
            label:const Text('Check saved state')),
          TextButton.icon(onPressed:savingKey==null?()=>unawaited(_retry()):null,
            icon:const Icon(Icons.refresh,size:18),
            label:const Text('Retry')),
        ]),
      ])),
    SwitchListTile(
      secondary:_icon('people_discoverable',Icons.person_search_outlined),
      title:const Text('Appear in people search'),
      subtitle:const Text('Allow other members to find your name and city.'),
      value:values['people_discoverable']==true,
      onChanged:savingKey==null
        ?(v)=>unawaited(_update('people_discoverable',v)):null,
    ),
    const Divider(height:1),
    ListTile(
      leading:_icon('profile_visibility',Icons.manage_accounts_outlined),
      title:const Text('Profile visibility'),
      subtitle:const Text('Who can see your biography and skills.'),
      trailing:DropdownButton<String>(
        underline:const SizedBox.shrink(),
        value:values['profile_visibility']=='public'?'public':'private',
        items:const [
          DropdownMenuItem(value:'private',child:Text('Private')),
          DropdownMenuItem(value:'public',child:Text('Public')),
        ],
        onChanged:savingKey==null?(v){
          if(v!=null)unawaited(_update('profile_visibility',v));
        }:null),
    ),
    const Divider(height:1),
    SwitchListTile(
      secondary:_icon('allow_calls',Icons.call_outlined),
      title:const Text('Allow voice and video calls'),
      subtitle:Text(widget.callingEnabled
        ?'Both people must agree and accept a connection.'
        :'Requires a calling-enabled app and an accepted connection.'),
      value:values['allow_calls']==true,
      onChanged:savingKey==null?(v)=>unawaited(_update('allow_calls',v)):null,
    ),
    const Divider(height:1),
    SwitchListTile(
      secondary:_icon('location_opt_in',Icons.location_on_outlined),
      title:const Text('Nearby discovery'),
      subtitle:const Text('Use an approximate location for nearby results.'),
      value:values['location_opt_in']==true,
      onChanged:savingKey==null?(v)=>unawaited(_nearby(v)):null,
    ),
    const Divider(height:1),
    SwitchListTile(
      secondary:_icon('notify_on',Icons.notifications_none),
      title:const Text('In-app activity alerts'),
      subtitle:Text(widget.pushEnabled
        ?'Receive activity alerts and configured notifications.'
        :'Show activity alerts while the app is open.'),
      value:values['notify_on']==true,
      onChanged:savingKey==null?(v)=>unawaited(_update('notify_on',v)):null,
    ),
  ]));
}

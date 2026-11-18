import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Active-call preferences. Auto-reconnection never resumes a declined/ended
/// call, nor does it silently activate a microphone or camera.
class ReachCallPrefs {
  String quality='auto';
  bool reconnect=true;
  bool adaptiveVideo=true;
  bool audioFallback=true;
  bool lowerData=false;
  int reconnectSeconds=45;

  static const keyPrefix='reach_call_v2_';
  static const validQualities=<String>['auto','saver','balanced','hd'];

  Future<void> load()async{
    final p=await SharedPreferences.getInstance();
    final value=p.getString('${keyPrefix}quality')??'auto';
    quality=validQualities.contains(value)?value:'auto';
    reconnect=p.getBool('${keyPrefix}reconnect')??true;
    adaptiveVideo=p.getBool('${keyPrefix}adaptive')??true;
    audioFallback=p.getBool('${keyPrefix}audio_fallback')??true;
    lowerData=p.getBool('${keyPrefix}lower_data')??false;
    reconnectSeconds=(p.getInt('${keyPrefix}reconnect_seconds')??45).clamp(15,60);
  }
  Future<void> save()async{
    final p=await SharedPreferences.getInstance();
    await p.setString('${keyPrefix}quality',quality);
    await p.setBool('${keyPrefix}reconnect',reconnect);
    await p.setBool('${keyPrefix}adaptive',adaptiveVideo);
    await p.setBool('${keyPrefix}audio_fallback',audioFallback);
    await p.setBool('${keyPrefix}lower_data',lowerData);
    await p.setInt('${keyPrefix}reconnect_seconds',reconnectSeconds);
  }
}

enum ReachLinkGrade {unknown,poor,fair,good}

class ReachLinkHealth {
  const ReachLinkHealth({this.availableBitrate,this.rttMilliseconds,this.lossPercent});
  final double? availableBitrate;
  final double? rttMilliseconds;
  final double? lossPercent;

  ReachLinkGrade get grade{
    final rate=availableBitrate,rtt=rttMilliseconds,loss=lossPercent;
    if(rate==null&&rtt==null&&loss==null)return ReachLinkGrade.unknown;
    if((rate!=null&&rate<250000)||(rtt!=null&&rtt>380)||(loss!=null&&loss>10)){
      return ReachLinkGrade.poor;
    }
    if((rate!=null&&rate<850000)||(rtt!=null&&rtt>170)||(loss!=null&&loss>4)){
      return ReachLinkGrade.fair;
    }
    return ReachLinkGrade.good;
  }
  bool get criticallyWeak =>
    (availableBitrate!=null&&availableBitrate!<120000) ||
    (lossPercent!=null&&lossPercent!>18);
}

class ReachVideoPlan {
  const ReachVideoPlan(this.bitrate,this.framesPerSecond,this.scale);
  final int bitrate,framesPerSecond;
  final double scale;
  static const saver=ReachVideoPlan(220000,12,3.0);
  static const balanced=ReachVideoPlan(650000,20,2.0);
  static const hd=ReachVideoPlan(1400000,26,1.0);

  static ReachVideoPlan choose(ReachCallPrefs config,ReachLinkGrade grade){
    if(config.lowerData||config.quality=='saver')return saver;
    if(config.quality=='balanced')return balanced;
    if(config.quality=='hd')return hd;
    if(!config.adaptiveVideo)return balanced;
    return switch(grade){
      ReachLinkGrade.poor=>saver,
      ReachLinkGrade.good=>hd,
      _=>balanced,
    };
  }
}

class ReachCallSettingsPage extends StatefulWidget {
  const ReachCallSettingsPage({super.key});
  @override State<ReachCallSettingsPage> createState()=>_ReachCallSettingsPageState();
}
class _ReachCallSettingsPageState extends State<ReachCallSettingsPage>{
  final config=ReachCallPrefs();
  bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    await config.load();
    if(mounted)setState(()=>loading=false);
  }
  void update(void Function() fn){
    setState(fn);
    config.save();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Calling & network')),
    body:SafeArea(child:loading?
      const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.all(16),children:[
        Text('Smart calling',style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:8),
        const Text('Keep voices clear and adjust video as bandwidth changes. '
          'An explicitly ended or declined call is never restarted automatically.'),
        const SizedBox(height:14),
        Card(child:Column(children:[
          SwitchListTile(
            secondary:const Icon(Icons.auto_awesome_outlined),
            title:const Text('Adaptive video'),
            subtitle:const Text('Adjust video data rate based on connection quality.'),
            value:config.adaptiveVideo,
            onChanged:(v)=>update(()=>config.adaptiveVideo=v)),
          const Divider(height:1),
          ListTile(
            leading:const Icon(Icons.high_quality),
            title:const Text('Video quality'),
            trailing:DropdownButton<String>(
              value:config.quality,
              items:const [
                DropdownMenuItem(value:'auto',child:Text('Smart')),
                DropdownMenuItem(value:'saver',child:Text('Saver')),
                DropdownMenuItem(value:'balanced',child:Text('Balanced')),
                DropdownMenuItem(value:'hd',child:Text('HD')),
              ],
              onChanged:(v){if(v!=null)update(()=>config.quality=v);},
            ),
          ),
          SwitchListTile(
            secondary:const Icon(Icons.data_saver_on_outlined),
            title:const Text('Save mobile data'),
            subtitle:const Text('Prefer smaller video even on good networks.'),
            value:config.lowerData,
            onChanged:(v)=>update(()=>config.lowerData=v)),
        ])),
        const SizedBox(height:11),
        Card(child:Column(children:[
          SwitchListTile(
            secondary:const Icon(Icons.settings_backup_restore),
            title:const Text('Auto-reconnect active calls'),
            subtitle:const Text('Try to recover after a temporary loss while '
              'the call remains open in the foreground.'),
            value:config.reconnect,
            onChanged:(v)=>update(()=>config.reconnect=v)),
          SwitchListTile(
            secondary:const Icon(Icons.graphic_eq),
            title:const Text('Audio-first fallback'),
            subtitle:const Text('Pause sending video when the connection '
              'becomes unusable; resume when stable.'),
            value:config.audioFallback,
            onChanged:(v)=>update(()=>config.audioFallback=v)),
          ListTile(
            title:const Text('Reconnection allowance'),
            subtitle:Text('${config.reconnectSeconds} seconds, then end the call'),
          ),
          Slider(
            value:config.reconnectSeconds.toDouble(),min:15,max:60,
            divisions:9,
            label:'${config.reconnectSeconds}s',
            onChanged:(v)=>update(()=>config.reconnectSeconds=v.round())),
        ])),
        const SizedBox(height:12),
        Text('Voice and video calling is an opt-in test feature until '
          'it passes multi-network device checks and relay configuration. '
          'Automatic recovery does not override call consent.',
          style:Theme.of(context).textTheme.bodySmall),
      ])));
}

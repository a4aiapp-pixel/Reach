import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only WhatsApp-style choices, never override receiver consent.
/// Roaming is detected by Android telephony; uncertainty means no auto-download.
enum ReachMediaKind { photo, audio, video, document }
enum ReachNetworkKind { mobile, wifi, roaming }

class ReachMediaPreferences {
  ReachMediaPreferences(this.prefs);
  final SharedPreferences prefs;
  static const MethodChannel _network=MethodChannel('reach/network');
  static String key(ReachNetworkKind network,ReachMediaKind kind) =>
    'reach_media_auto_${network.name}_${kind.name}';

  static ReachMediaKind classify(String mime){
    if(mime.startsWith('image/'))return ReachMediaKind.photo;
    if(mime.startsWith('audio/'))return ReachMediaKind.audio;
    if(mime.startsWith('video/'))return ReachMediaKind.video;
    return ReachMediaKind.document;
  }
  static bool defaultFor(ReachNetworkKind net,ReachMediaKind kind){
    if(net==ReachNetworkKind.roaming)return false;
    if(net==ReachNetworkKind.mobile)return kind==ReachMediaKind.photo;
    return kind==ReachMediaKind.photo||kind==ReachMediaKind.audio;
  }
  bool allows(ReachNetworkKind net,ReachMediaKind kind)=>
    prefs.getBool(key(net,kind))??defaultFor(net,kind);
  Future<void> set(ReachNetworkKind net,ReachMediaKind kind,bool enabled)=>
    prefs.setBool(key(net,kind),enabled);
  static Future<ReachMediaPreferences> load()async=>
    ReachMediaPreferences(await SharedPreferences.getInstance());

  Future<ReachNetworkKind?> currentNetwork()async{
    final types=await Connectivity().checkConnectivity();
    if(types.contains(ConnectivityResult.none)||types.isEmpty)return null;
    if(types.contains(ConnectivityResult.wifi)||
       types.contains(ConnectivityResult.ethernet))return ReachNetworkKind.wifi;
    if(types.contains(ConnectivityResult.mobile)){
      try{
        final roaming=await _network.invokeMethod<bool>('isRoaming');
        if(roaming==null)return ReachNetworkKind.roaming;
        return roaming?ReachNetworkKind.roaming:ReachNetworkKind.mobile;
      }catch(_){
        // Unknown roaming state => never silently consume cellular data.
        return ReachNetworkKind.roaming;
      }
    }
    return null;
  }
  Future<bool> shouldAutoDownload(String mime,{int bytes=0})async{
    final net=await currentNetwork();
    if(net==null||bytes>8*1024*1024)return false;
    return allows(net,classify(mime));
  }
}

class ReachMediaSettingsPage extends StatefulWidget {
  const ReachMediaSettingsPage({super.key});
  @override State<ReachMediaSettingsPage> createState()=>_ReachMediaSettingsPageState();
}
class _ReachMediaSettingsPageState extends State<ReachMediaSettingsPage>{
  ReachMediaPreferences? settings;
  ReachNetworkKind network=ReachNetworkKind.wifi;
  @override void initState(){
    super.initState();
    ReachMediaPreferences.load().then((value){
      if(mounted)setState(()=>settings=value);
    });
  }

  static const captions={
    ReachMediaKind.photo:('Photos',Icons.image_outlined),
    ReachMediaKind.audio:('Audio',Icons.audiotrack_outlined),
    ReachMediaKind.video:('Videos',Icons.video_library_outlined),
    ReachMediaKind.document:('Documents',Icons.description_outlined),
  };

  @override Widget build(BuildContext context){
    final selected=settings;
    return Scaffold(
      appBar:AppBar(title:const Text('Media downloads')),
      body:SafeArea(child:selected==null?
        const Center(child:CircularProgressIndicator()):
        ListView(padding:const EdgeInsets.all(16),children:[
          Text('Automatic downloads',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          SegmentedButton<ReachNetworkKind>(
            segments:const [
              ButtonSegment(value:ReachNetworkKind.mobile,
                icon:Icon(Icons.signal_cellular_alt),label:Text('Mobile')),
              ButtonSegment(value:ReachNetworkKind.wifi,
                icon:Icon(Icons.wifi),label:Text('Wi-Fi')),
              ButtonSegment(value:ReachNetworkKind.roaming,
                icon:Icon(Icons.public),label:Text('Roaming')),
            ],
            selected:{network},
            onSelectionChanged:(values)=>setState(()=>network=values.first)),
          const SizedBox(height:15),
          Card(child:Column(children:[
            for(final kind in ReachMediaKind.values)...[
              if(kind!=ReachMediaKind.photo)const Divider(height:1),
              SwitchListTile.adaptive(
                secondary:Icon(captions[kind]!.$2),
                title:Text(captions[kind]!.$1),
                value:selected.allows(network,kind),
                onChanged:(next)async{
                  await selected.set(network,kind,next);
                  if(mounted)setState((){});
                }),
            ]
          ])),
          const SizedBox(height:12),
          Text('Off means tap to download. Mobile roaming is detected '
            'conservatively; unrecognized networks never auto-download. '
            'Large files always require a tap.',
            style:Theme.of(context).textTheme.bodySmall),
          const SizedBox(height:12),
          Card(child:ListTile(
            leading:const Icon(Icons.storage_outlined),
            title:const Text('Private attachment limits'),
            subtitle:const Text('Photos 8 MB · Audio 12 MB · '
              'Videos 24 MB · Documents 16 MB'),
          )),
          const SizedBox(height:7),
          Text('Your choices stay on this device. Only files from accepted '
            'connections are eligible. Private media also requires consent '
            'from both members.',
            style:Theme.of(context).textTheme.bodySmall),
        ])),
    );
  }
}

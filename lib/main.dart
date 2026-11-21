import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'models.dart';
import 'repository.dart';
import 'push_service.dart';
import 'reach_auth_providers.dart';
import 'reach_themes.dart';
import 'reach_navigation.dart';
import 'reach_group_workspace.dart';
import 'reach_group_add.dart';
import 'reach_avatar.dart';
import 'reach_experience.dart';
import 'reach_calls_hub.dart';
import 'reach_discover_design.dart';
import 'chat_attachment_panel.dart';
import 'business_studio.dart';
import 'reach_calling.dart';
import 'reach_assist.dart';
import 'reach_legal_sheet.dart';
import 'community_catalog.dart';
import 'geo_places.dart';
import 'reach_permission_intro.dart';
import 'reach_people.dart';
import 'reach_age_gate.dart';
import 'reach_settings.dart';

late final ReachRepository reach;
// Categories and starter group templates are centralized in community_catalog.dart.
const seed = Color(0xFF635CF4);
final formatTime = DateFormat('d MMM · h:mm a');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.ready) {
    await Supabase.initialize(url: AppConfig.url, publishableKey: AppConfig.key,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce));
    reach = ReachRepository(Supabase.instance.client);
  }
  runApp(const ReachApp());
}

class ReachApp extends StatefulWidget {
  const ReachApp({super.key});
  @override State<ReachApp> createState()=>_ReachAppState();
}
class _ReachAppState extends State<ReachApp> {
  ThemeMode themeMode = ThemeMode.system;
  String lookId = 'aurora';
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    final v=p.getString('theme')??'system';
    final selected=p.getString('reach_visual_preset')??'aurora';
    if(mounted) setState((){
      themeMode=v=='dark'?ThemeMode.dark:v=='light'?ThemeMode.light:ThemeMode.system;
      lookId=reachLookById(selected).id;
    });
  }
  Future<void> _changeTheme(ThemeMode t) async {
    setState(()=>themeMode=t);
    final p=await SharedPreferences.getInstance();
    await p.setString('theme',t.name);
  }
  Future<void> _changeLook(String next) async {
    setState(()=>lookId=reachLookById(next).id);
    final p=await SharedPreferences.getInstance();
    await p.setString('reach_visual_preset',lookId);
  }
  @override Widget build(BuildContext context){
    final look=reachLookById(lookId);
    final effectiveMode=themeMode==ThemeMode.system&&look.preferDark?ThemeMode.dark:themeMode;
    return MaterialApp(title:'Reach — Help, right when it matters',debugShowCheckedModeBanner:false,
      theme:look.build(Brightness.light),darkTheme:look.build(Brightness.dark),themeMode:effectiveMode,
      home: !AppConfig.ready ? const ConfigurationPage() :
        StreamBuilder<AuthState>(stream:Supabase.instance.client.auth.onAuthStateChange,
          builder:(context,snapshot){
            final session=Supabase.instance.client.auth.currentSession;
            if(session==null) return const AuthPage();
            if(snapshot.data?.event == AuthChangeEvent.passwordRecovery) return const PasswordRecoveryPage();
            return ReachHome(onTheme:_changeTheme,themeMode:themeMode,
              lookId:lookId,onLook:_changeLook);
          }),
    );
  }
}

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(body:SafeArea(child:Center(child:
    ConstrainedBox(constraints:const BoxConstraints(maxWidth:450),child:Padding(
      padding:const EdgeInsets.all(26), child:Column(mainAxisSize:MainAxisSize.min,
      children:[const ReachMark(size:78),const SizedBox(height:25),
      Text('Reach',style:Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:8),const Text('A new way to be available to each other.',textAlign:TextAlign.center),
      const SizedBox(height:26),const Icon(Icons.settings_suggest_outlined,size:40),const SizedBox(height:12),
      const Text('Backend configuration required',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:12),const Text('This source project is ready to connect to your own Supabase instance. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY at build time and run the included database migration. No fictional users or fake live activity are shown.',textAlign:TextAlign.center),
      const SizedBox(height:15),const SelectableText('flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY',textAlign:TextAlign.center),
      const SizedBox(height:12),const Text('See README.md for the guided setup.',textAlign:TextAlign.center),
      ]))))));
}
class ReachMark extends StatelessWidget {
  const ReachMark({super.key,this.size=50});final double size;
  @override Widget build(BuildContext context)=>ClipRRect(
    borderRadius:BorderRadius.circular(size*.24),
    child:Image.asset('assets/branding/reach_selected_icon.webp',
      width:size,height:size,fit:BoxFit.cover,filterQuality:FilterQuality.high,
      semanticLabel:'Reach — three connected people in a location pin'));
}

Future<T?> busy<T>(BuildContext context,Future<T> Function() work,{String? success}) async {
  try { final result=await work(); if(context.mounted && success!=null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(success)));
  }return result;
  }catch(e){if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(humanError(e)),behavior:SnackBarBehavior.floating));
  }return null;}
}
String humanError(Object e){
  if(e is AuthException)return e.message;
  if(e is PostgrestException)return e.message;
  if(e is TimeoutException)return 'Reach could not contact its server. Check Wi-Fi or mobile data and retry.';
  final raw=e.toString();
  final lower=raw.toLowerCase();
  if(lower.contains('socketexception')||lower.contains('clientexception')||
      lower.contains('connection timed out')||lower.contains('failed host lookup')||
      lower.contains('network is unreachable')||lower.contains('handshakeexception')){
    return 'Reach could not contact its server. Check Wi-Fi or mobile data and retry.';
  }
  return raw.replaceFirst('Exception: ','').replaceFirst('Bad state: ','');
}

void popSafe(BuildContext context){if(context.mounted && Navigator.canPop(context)) Navigator.pop(context);}
Widget gap(double h)=>SizedBox(height:h);


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState()=>_AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email=TextEditingController(),pass=TextEditingController(),
    name=TextEditingController(),username=TextEditingController(),
    verifyCode=TextEditingController();
  bool signup=false,loading=false,hide=true,agreed=false,awaitingConfirmation=false;
  late final Future<bool> googleAvailable;
  @override void initState(){super.initState();googleAvailable=ReachAuthProviders.googleEnabled();}
  @override void dispose(){
    email.dispose();pass.dispose();name.dispose();username.dispose();
    verifyCode.dispose();super.dispose();
  }
  Future<void> action(Future<void> Function() fn,{String? success}) async {
    setState(()=>loading=true);
    await busy(context,fn,success:success);
    if(mounted)setState(()=>loading=false);
  }
  void emailAction(Future<void> Function(String) fn, String success){
    final address=email.text.trim();
    if(!address.contains('@')){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Please enter your email address first.')));
      return;
    }
    action(()=>fn(address),success:success);
  }
  Future<void> createAccount() async {
    setState(()=>loading=true);
    try {
      await reach.signUp(email.text.trim(),pass.text,name.text,username.text);
      if(mounted){
        setState((){
          signup=false;
          awaitingConfirmation=true;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Check your inbox to confirm your email address.')));
      }
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(humanError(e))));
    }finally{
      if(mounted)setState(()=>loading=false);
    }
  }
  void submit(){
    if(loading)return;
    final identifier=email.text.trim();
    if(identifier.isEmpty||pass.text.length<8||
       (signup&&(!identifier.contains('@')||name.text.trim().length<2||
       !RegExp(r'^[a-z][a-z0-9_]{2,23}$').hasMatch(username.text.trim().toLowerCase())))){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(signup
        ? 'Enter your name, email, a 3–24 character username and an 8+ character password.'
        : 'Enter your email or username and password of at least 8 characters.')));
      return;
    }
    if(signup&&!agreed){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Accept the community rules to continue.')));
      return;
    }
    if(signup){createAccount();}
    else{action(()=>reach.signIn(identifier,pass.text));}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(
    child:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(26),
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Center(child:ReachMark(size:70)),gap(20),
          Text('Reach',textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.w900)),
          const Text('Offer help. Find support. Connect on your terms.',textAlign:TextAlign.center),
          gap(25),
          Text(signup?'Create your account':'Welcome back',
            style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
          gap(16),
          if(signup)...[
            TextField(controller:name,textCapitalization:TextCapitalization.words,
              decoration:const InputDecoration(labelText:'Your display name',
                prefixIcon:Icon(Icons.person_outline))),gap(12),
            TextField(controller:username,maxLength:24,autocorrect:false,
              textCapitalization:TextCapitalization.none,
              decoration:const InputDecoration(labelText:'Unique username',
                hintText:'e.g. reach_helper',
                helperText:'3–24 letters, digits or underscores. Must begin with a letter.',
                prefixIcon:Icon(Icons.alternate_email))),gap(12),
          ],
          TextField(controller:email,
            keyboardType:signup?TextInputType.emailAddress:TextInputType.text,
            autofillHints:signup?const [AutofillHints.email]:const [AutofillHints.username],
            autocorrect:false,textCapitalization:TextCapitalization.none,
            decoration:InputDecoration(
              labelText:signup?'Email address':'Email or username',
              prefixIcon:const Icon(Icons.person_outline))),gap(12),
          TextField(controller:pass,obscureText:hide,
            autofillHints:[signup?AutofillHints.newPassword:AutofillHints.password],
            decoration:InputDecoration(labelText:'Password',
              prefixIcon:const Icon(Icons.lock_outline),
              suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),
                icon:Icon(hide?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
          if(signup)...[gap(12),CheckboxListTile(
            contentPadding:EdgeInsets.zero,
            controlAffinity:ListTileControlAffinity.leading,
            title:const Text('I am 18 or older and agree to the community rules and privacy notice.',
              style:TextStyle(fontSize:13)),
            value:agreed,onChanged:(v)=>setState(()=>agreed=v??false)),
            Align(alignment:Alignment.centerLeft,
              child:TextButton.icon(
                onPressed:()=>showReachLegalSummary(context),
                icon:const Icon(Icons.policy_outlined),
                label:const Text('Read privacy and community rules'))),
          ],
          gap(16),
          FilledButton(onPressed:loading?null:submit,
            child:Padding(padding:const EdgeInsets.all(13),
              child:Text(signup?'Create account':'Sign in'))),
          gap(12),
          if(AppConfig.googleSignInEnabled)
            FutureBuilder<bool>(future:googleAvailable,builder:(context,snapshot){
              if(snapshot.data!=true)return const SizedBox.shrink();
              return OutlinedButton.icon(onPressed:loading?null:()=>action(reach.googleSignIn),
                icon:const Icon(Icons.account_circle_outlined),
                label:const Text('Continue with Google'));
            }),
          TextButton(onPressed:loading?null:()=>setState((){
            signup=!signup;awaitingConfirmation=false;
          }),child:Text(signup?'Already registered? Sign in':'New here? Create an account')),
          if(!signup)...[
            if(awaitingConfirmation)...[
              gap(10),
              const Text('Confirm your email with the link sent to your inbox. If the email also contains a 6-digit code, you can verify it here.',
                textAlign:TextAlign.center),
              gap(10),
              TextField(controller:verifyCode,maxLength:6,
                keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'6-digit verification code (if provided)',
                  prefixIcon:Icon(Icons.verified_outlined))),
              FilledButton.tonal(onPressed:loading?null:(){
                if(!email.text.trim().contains('@')||
                   !RegExp(r'^[0-9]{6}$').hasMatch(verifyCode.text.trim())){
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:Text('Enter your email and its 6-digit confirmation code.')));
                  return;
                }
                action(()=>reach.verifySignupCode(email.text.trim(),verifyCode.text.trim()),
                  success:'Email verified successfully.');
              },child:const Text('Verify email code')),
              TextButton(onPressed:()=>setState(()=>awaitingConfirmation=false),
                child:const Text('I confirmed my email — sign in')),
            ],
            Wrap(alignment:WrapAlignment.center,spacing:4,children:[
              TextButton(onPressed:loading?null:()=>emailAction(reach.magicLink,
                'Check your email for the sign-in link.'),
                child:const Text('Email me a sign-in link')),
              TextButton(onPressed:loading?null:()=>emailAction(reach.resetPassword,
                'Password reset email requested.'),
                child:const Text('Forgot password?')),
              TextButton(onPressed:loading?null:()=>emailAction(reach.resendSignup,
                'If your address is awaiting confirmation, another email will be sent.'),
                child:const Text('Resend verification')),
            ]),
          ],
          gap(10),
          const Text('Your availability is voluntary. Your exact GPS position is never published.',
            textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.grey)),
        ]))))));
}

class ReachHome extends StatefulWidget {
  const ReachHome({super.key,required this.onTheme,required this.themeMode,
    required this.lookId,required this.onLook});
  final ValueChanged<ThemeMode> onTheme;final ThemeMode themeMode;
  final String lookId;final ValueChanged<String> onLook;
  @override State<ReachHome> createState()=>_ReachHomeState();
}
class _ReachHomeState extends State<ReachHome>{
  int page=0;int revision=0;bool ready=false;bool showIntro=false;
  Map<String,dynamic> profile={};
  final Set<int> visitedPages={0};
  final GlobalKey<_InboxPageState> inboxKey=GlobalKey<_InboxPageState>();
  StreamSubscription<List<Map<String,dynamic>>>? alertUpdates;
  final Set<String> knownAlerts={};
  bool alertsInitialized=false;
  int unreadAlerts=0;
  @override void dispose(){
    alertUpdates?.cancel();
    unawaited(ReachPush.dispose());
    super.dispose();
  }
  void watchLiveAlerts(){
    if(alertUpdates!=null||reach.uid.isEmpty)return;
    alertUpdates=Supabase.instance.client.from('alerts')
      .stream(primaryKey:['id']).eq('user_id',reach.uid)
      .order('created_at',ascending:false).limit(50)
      .listen((rows){
        if(!mounted)return;
        final fresh=alertsInitialized
          ? rows.where((item)=>!knownAlerts.contains(str(item['id']))).toList()
          : <Map<String,dynamic>>[];
        knownAlerts..clear()..addAll(rows.map((item)=>str(item['id'])));
        alertsInitialized=true;
        final unread=rows.where((item)=>item['read_at']==null).length;
        if(unread!=unreadAlerts)setState(()=>unreadAlerts=unread);
        if(fresh.isNotEmpty){
          if(page==1&&inboxKey.currentState?.tab==2){
            unawaited(inboxKey.currentState!.refresh());
          }
          if(profile['notify_on']==true){
            final latest=fresh.first;
            final messenger=ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(SnackBar(
              behavior:SnackBarBehavior.floating,
              duration:const Duration(seconds:5),
              content:Text('${str(latest['title'])}: ${str(latest['body'])}',
                maxLines:2,overflow:TextOverflow.ellipsis),
              action:SnackBarAction(label:'Inbox',onPressed:(){
                if(mounted)setState((){page=1;visitedPages.add(1);});
              }),
            ));
          }
        }
      },onError:(Object e){
        debugPrint('Reach live alerts unavailable: $e');
      });
  }
  @override void initState(){super.initState();load();setupPush();}
  Future<void> setupPush() async {
    if(await ReachPush.prepare()) {
      try {await ReachPush.register(Supabase.instance.client);} catch (_) {/* user can deny notifications */}
    }
  }
  Future<void> load() async {
    final p=await busy(context,reach.profile);
    if(p==null)return;
    final prefs=await SharedPreferences.getInstance();
    final introDone=prefs.getBool('reach_permissions_intro_done_${reach.uid}')??false;
    if(mounted)setState((){
      profile=p;ready=true;showIntro=!introDone;
    });
    if(mounted)watchLiveAlerts();
  }
  // Preference writes already return the verified database row. Refresh the
  // parent snapshot quietly, never stacking a secondary RPC error on a switch
  // that has just been acknowledged as saved.
  Future<void> refreshProfileQuietly() async {
    try {
      final updated=await reach.profile().timeout(const Duration(seconds:16));
      if(mounted)setState(()=>profile=updated);
    }catch(e){
      debugPrint('Reach preference profile refresh failed: ${humanError(e)}');
    }
  }

  Future<void> finishPermissionIntro() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('reach_permissions_intro_done_${reach.uid}',true);
    if(mounted)setState(()=>showIntro=false);
  }
  Future<bool> enableNearbyDuringIntro() async {
    try {
      await reach.setApproxLocation();
      await finishPermissionIntro();
      return true;
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(humanError(e))));
      return false;
    }
  }
  void refreshed(){setState(()=>revision++);}
  @override Widget build(BuildContext context){
    if(!ready) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(profile['terms_accepted_at']==null||str(profile['city']).trim().isEmpty||str(profile['country']).trim().isEmpty){
      return ProfileSetup(onComplete:(){load();});
    }
    if(profile['adult_self_attested_at']==null)return ReachAdultGate(onComplete:load);
    if(showIntro)return ReachPermissionIntro(
      onEnableNearby:enableNearbyDuringIntro,
      onContinueWithout:finishPermissionIntro,
    );
    final pages=<Widget>[
       DiscoverPage(key:ValueKey('discover$revision'),onCreated:refreshed),
       visitedPages.contains(1)?InboxPage(key:inboxKey):const SizedBox.shrink(),
       visitedPages.contains(2)?ReachCallsHub(
         onOpenConversation:(c)=>Navigator.push(context,MaterialPageRoute(
           builder:(_)=>ChatPage(
             conversationId:str(c['id']),peerId:str(c['peer_id']),
             peerName:str(c['peer_name']),topic:str(c['post_title']))))):const SizedBox.shrink(),
       visitedPages.contains(3)?const CirclesPage():const SizedBox.shrink(),
       visitedPages.contains(4)?ProfilePage(
          profile:profile,onChanged:()=>unawaited(refreshProfileQuietly()),
          onTheme:widget.onTheme,themeMode:widget.themeMode,
          lookId:widget.lookId,onLook:widget.onLook,
          onMyReach:()=>Navigator.push(context,MaterialPageRoute(
             builder:(_)=>MinePage(onCreated:refreshed)))):const SizedBox.shrink(),
     ];
     void selectPage(int i){
        setState((){page=i;visitedPages.add(i);});
        if(i==1)WidgetsBinding.instance.addPostFrameCallback((_){
          if(mounted&&inboxKey.currentState!=null){
            unawaited(inboxKey.currentState!.refresh());
          }
        });
      }
      final rail=ReachAdaptiveNavigation.shouldUseRail(context);
      return Scaffold(
        body:rail
          ?Row(children:[
              ReachAdaptiveRail(selectedIndex:page,onSelected:selectPage,
                unreadCount:unreadAlerts),
              const VerticalDivider(width:1,thickness:1),
              Expanded(child:IndexedStack(index:page,children:pages)),
            ])
          :IndexedStack(index:page,children:pages),
        bottomNavigationBar:rail?null:ReachAdaptiveNavigation(
          selectedIndex:page,onSelected:selectPage,
          unreadCount:unreadAlerts),
        floatingActionButton:page==0?FloatingActionButton.extended(
          tooltip:'Create an offer or request',
          onPressed:()async {
            final saved=await Navigator.push<bool>(context,
              MaterialPageRoute(builder:(_)=>const ComposePage()));
            if(saved==true)refreshed();
          },
          icon:const Icon(Icons.add_rounded),label:const Text('Create Reach')):null,
      );
  }
}

class ProfileSetup extends StatefulWidget{const ProfileSetup({super.key,required this.onComplete});final VoidCallback onComplete;@override State<ProfileSetup> createState()=>_ProfileSetupState();}
class _ProfileSetupState extends State<ProfileSetup>{
 final city=TextEditingController(),country=TextEditingController(),name=TextEditingController();bool agree=false;
 @override void dispose(){city.dispose();country.dispose();name.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Set up Reach')),
 body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
   const ReachMark(),gap(20),Text('Make Reach yours',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
   const Text('Your city and country help discover relevant offers. You can use Reach without GPS.'),gap(20),
   TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Display name (optional)')),
   gap(12),GeoAutocompleteField(controller:country,type:GeoFieldType.country,
       clearCityOnCountryChange:city,required:true),
   gap(12),
   GeoAutocompleteField(controller:city,type:GeoFieldType.city,
       countryController:country,required:true),
   const Padding(padding:EdgeInsets.symmetric(vertical:6),
     child:Text('Place suggestions: GeoNames · CC BY 4.0 · offline.',
       style:TextStyle(fontSize:11))),
   gap(12),CheckboxListTile(value:agree,onChanged:(v)=>setState(()=>agree=v??false),
     title:const Text('I am 18 or older and accept the community rules and privacy policy.'),
     subtitle:const Text('No harassment, fraud, unsafe requests, unwanted contacts, or impersonation.')),
   TextButton.icon(onPressed:()=>showReachLegalSummary(context),
     icon:const Icon(Icons.policy_outlined),
     label:const Text('Review privacy and community rules')),
   gap(16),FilledButton(onPressed:()=>busy(context,()async {
     if(city.text.trim().isEmpty||country.text.trim().isEmpty||!agree) throw StateError('Enter your city/country and accept the rules.');
     await reach.updateProfile({'city':city.text.trim(),
       'country':GeoDirectory.canonicalCountry(country.text)??country.text.trim(),
       if(name.text.trim().isNotEmpty)'display_name':name.text.trim(),
       'terms_accepted_at':DateTime.now().toUtc().toIso8601String()});widget.onComplete();
   }),child:const Padding(padding:EdgeInsets.all(14),child:Text('Start using Reach'))),
   TextButton(onPressed:()=>busy(context,reach.signOut),child:const Text('Use a different account')),
 ])));
}

Widget sectionHeader(BuildContext context,String title,{String? subtitle,Widget? trailing})=>
  Padding(padding:const EdgeInsets.fromLTRB(4,10,4,10),child:Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
      if(subtitle!=null)Text(subtitle,style:Theme.of(context).textTheme.bodySmall),])),
    if(trailing!=null)trailing]));
Widget emptyState(BuildContext context,IconData icon,String title,String subtitle)=>
  Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,
  children:[Icon(icon,size:54,color:Theme.of(context).colorScheme.primary),gap(12),
    Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),gap(5),
    Text(subtitle,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium)])));

class DiscoverPage extends StatefulWidget {
 const DiscoverPage({super.key,required this.onCreated});final VoidCallback onCreated;
 @override State<DiscoverPage> createState()=>_DiscoverPageState();
}
class _DiscoverPageState extends State<DiscoverPage>{
 String area='city',category='All',kind='All';int radius=25;bool loading=true;
 List<ReachPost> posts=[];final search=TextEditingController();Timer? debounce;
 int requestGeneration=0;
 @override void initState(){super.initState();refresh();}
 @override void dispose(){debounce?.cancel();search.dispose();super.dispose();}
 Future<void> refresh() async {
  if(!mounted)return;
  final ticket=++requestGeneration;
  setState(()=>loading=true);
  final result=await busy(context,()=>reach.discover(area:area,category:category,
    kind:kind,keyword:search.text,radiusKm:radius));
  // Avoid stale results after fast successive changes to search/filter.
  if(mounted&&ticket==requestGeneration){
    setState((){if(result!=null)posts=result;loading=false;});
  }
 }
 Future<void> chooseFilters()async{
   String nextCategory=category,nextKind=kind;
   final selected=await showModalBottomSheet<List<String>>(
     context:context,isScrollControlled:true,
     builder:(sheet)=>StatefulBuilder(builder:(sheet,repaint)=>SafeArea(
       top:false,child:Padding(padding:EdgeInsets.fromLTRB(
         20,8,20,MediaQuery.viewInsetsOf(sheet).bottom+22),
         child:Column(mainAxisSize:MainAxisSize.min,
           crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Text('Refine discovery',
             style:Theme.of(sheet).textTheme.titleLarge),
           const SizedBox(height:16),
           DropdownButtonFormField<String>(
             initialValue:nextCategory,isExpanded:true,
             decoration:const InputDecoration(labelText:'Category'),
             items:categories.map((item)=>DropdownMenuItem(
               value:item,child:Text(item,overflow:TextOverflow.ellipsis))).toList(),
             onChanged:(v)=>repaint(()=>nextCategory=v??'All')),
           const SizedBox(height:12),
           DropdownButtonFormField<String>(
             initialValue:nextKind,isExpanded:true,
             decoration:const InputDecoration(labelText:'Type'),
             items:const [
               DropdownMenuItem(value:'All',child:Text('Everything')),
               DropdownMenuItem(value:'offer',child:Text('Offers')),
               DropdownMenuItem(value:'request',child:Text('Requests'))],
             onChanged:(v)=>repaint(()=>nextKind=v??'All')),
           const SizedBox(height:18),
           FilledButton.icon(
             onPressed:()=>Navigator.pop(sheet,[nextCategory,nextKind]),
             icon:const Icon(Icons.check),label:const Text('Apply filters')),
         ])))));
   if(selected!=null && selected.length==2 && mounted){
     setState((){category=selected[0];kind=selected[1];});
     await refresh();
   }
 }
 @override Widget build(BuildContext context){
  final look=ReachDesign.of(context);
  final shortScreen=MediaQuery.sizeOf(context).height<740;
  return SafeArea(child:Column(children:[
  Padding(padding:EdgeInsets.fromLTRB(look.gutter,look.compact?8:12,look.gutter,0),
    child:Column(children:[
      if(shortScreen)
        Row(children:[
          const ReachMark(size:31),
          const SizedBox(width:10),
          Expanded(child:Text('Reach · Explore',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight:FontWeight.w900))),
          IconButton(tooltip:'Find people',
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>ReachPeoplePage(chatBuilder:(id,peer,name)=>
                ChatPage(conversationId:id,peerId:peer,
                  peerName:name,topic:'Direct connection')))),
            icon:const Icon(Icons.people_alt_outlined)),
          IconButton(tooltip:'Reach Assist',
            onPressed:()=>Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const ReachAssistPage())),
            icon:const Icon(Icons.auto_awesome_outlined)),
          IconButton(tooltip:'Refresh',onPressed:refresh,
            icon:const Icon(Icons.refresh_rounded)),
        ])
      else ...[
        ReachDiscoverHero(
          onPeople:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>ReachPeoplePage(chatBuilder:(id,peer,name)=>
              ChatPage(conversationId:id,peerId:peer,
                peerName:name,topic:'Direct connection')))),
          onAssist:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>const ReachAssistPage())),
          onRefresh:refresh),
        gap(look.compact?9:13),
        ReachActionStrip(actions:[
          ReachQuickAction('Offer',Icons.favorite_outline,()async{
            final saved=await Navigator.push<bool>(context,MaterialPageRoute(
              builder:(_)=>const ComposePage(initialType:'offer')));
            if(saved==true)widget.onCreated();
          }),
          ReachQuickAction('Request',Icons.pan_tool_alt_outlined,()async{
            final saved=await Navigator.push<bool>(context,MaterialPageRoute(
              builder:(_)=>const ComposePage(initialType:'request')));
            if(saved==true)widget.onCreated();
          }),
          ReachQuickAction('Groups',Icons.groups_2_outlined,()=>
            Navigator.push(context,MaterialPageRoute(
              builder:(_)=>const CirclesPage()))),
          ReachQuickAction('My activity',Icons.bolt_outlined,()=>
            Navigator.push(context,MaterialPageRoute(
              builder:(_)=>MinePage(onCreated:widget.onCreated)))),
        ]),
      ],
      gap(look.compact?8:12),
    TextField(controller:search,onChanged:(_){debounce?.cancel();debounce=Timer(const Duration(milliseconds:400),refresh);},
      decoration:const InputDecoration(hintText:'Search help, skills or opportunities',prefixIcon:Icon(Icons.search_rounded))),gap(13),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final a in const {'nearby':'Near me','city':'My city','country':'My country','global':'Worldwide'}.entries)
        Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(a.value),selected:area==a.key,
          onSelected:(_){setState(()=>area=a.key);refresh();})),
    ])),gap(6),
    if(look.filters==ReachFilterLayout.sheet || shortScreen)
      SizedBox(width:double.infinity,
        child:OutlinedButton.icon(onPressed:chooseFilters,
          icon:const Icon(Icons.tune_rounded,size:19),
          label:Text('Filters · ${category=='All'?'All topics':category} · ${kind=='All'?'All':kind}',
            maxLines:1,overflow:TextOverflow.ellipsis))),
    if(look.filters==ReachFilterLayout.inline && !shortScreen)
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(
          initialValue:category,isExpanded:true,
          decoration:const InputDecoration(labelText:'Category',isDense:true),
          items:categories.map((e)=>DropdownMenuItem(value:e,
            child:Text(e,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v){setState(()=>category=v??'All');refresh();})),
        const SizedBox(width:8),
        Expanded(child:DropdownButtonFormField<String>(
          initialValue:kind,isExpanded:true,
          decoration:const InputDecoration(labelText:'Type',isDense:true),
          items:const [
            DropdownMenuItem(value:'All',child:Text('Everything')),
            DropdownMenuItem(value:'offer',child:Text('Offers')),
            DropdownMenuItem(value:'request',child:Text('Requests'))],
          onChanged:(v){setState(()=>kind=v??'All');refresh();})),
      ]),
    if(area=='nearby')Row(children:[
      Expanded(child:Text('Within $radius km · approximate area',style:Theme.of(context).textTheme.bodySmall)),
      PopupMenuButton<int>(tooltip:'Nearby radius',onSelected:(v){setState(()=>radius=v);refresh();},
        itemBuilder:(_)=>[5,10,25,50,100].map((v)=>PopupMenuItem(value:v,child:Text('$v km'))).toList(),
        child:const Padding(padding:EdgeInsets.all(8),child:Icon(Icons.tune_rounded))),
      TextButton.icon(onPressed:()=>busy(context,()async {
          await reach.setApproxLocation();await reach.updateProfile({'location_opt_in':true});await refresh();
        },success:'Approximate location updated.'),
        icon:const Icon(Icons.my_location,size:16),label:const Text('Enable location')),
    ]),
    gap(10),
  ])),
  Expanded(child:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,
    child:posts.isEmpty?ListView(children:[SizedBox(height:MediaQuery.sizeOf(context).height*.17),
      emptyState(context,Icons.travel_explore_rounded,'Nothing matching yet',
      'Try another location or category. Your community grows with every new reach.')]):
      LayoutBuilder(builder:(context,constraints){
        final columns=look.feed==ReachFeedLayout.bento && constraints.maxWidth>=610;
        if(columns){
          return GridView.builder(
            padding:EdgeInsets.fromLTRB(look.gutter,0,look.gutter,90),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:2,childAspectRatio:1.14,
              crossAxisSpacing:14,mainAxisSpacing:12),
            itemCount:posts.length,
            itemBuilder:(c,i)=>ReachCard(post:posts[i],
              onTap:()=>showReachDetail(context,posts[i],onChanged:refresh)),
          );
        }
        return ListView.builder(
          padding:EdgeInsets.fromLTRB(look.gutter,0,look.gutter,90),
          itemCount:posts.length,
          itemBuilder:(c,i)=>ReachCard(post:posts[i],
            onTap:()=>showReachDetail(context,posts[i],onChanged:refresh)),
        );
      }))),
 ]));
 }
}

class ReachCard extends StatelessWidget {
  const ReachCard({super.key,required this.post,required this.onTap,this.owner=false});
  final ReachPost post;
  final VoidCallback onTap;
  final bool owner;

  @override Widget build(BuildContext context){
    final look=ReachDesign.of(context);
    final scheme=Theme.of(context).colorScheme;
    final text=Theme.of(context).textTheme;
    final offer=post.kind=='offer';
    final accent=offer?scheme.primary:scheme.tertiary;
    final status=offer?'OFFERING HELP':'NEEDS HELP';
    final categoryLocation='${post.category} · ${post.city}';
    final action=owner?'Manage':'Connect';

    if(look.feed==ReachFeedLayout.glass){
      // Coastal: airy glass-like cards with a large identity avatar and
      // restrained information architecture rather than stacked tag grids.
      return Card(margin:const EdgeInsets.only(bottom:14),
        clipBehavior:Clip.antiAlias,
        child:InkWell(onTap:onTap,child:Padding(
          padding:const EdgeInsets.all(17),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              CircleAvatar(radius:22,
                backgroundColor:accent.withValues(alpha:.14),
                child:Icon(offer?Icons.favorite_border:
                  Icons.pan_tool_alt_outlined,color:accent)),
              const SizedBox(width:11),
              Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(post.ownerName.isEmpty?'Reach member':post.ownerName,
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:text.titleSmall?.copyWith(fontWeight:FontWeight.w800)),
                Text('${post.city} · ${timeago.format(post.createdAt)}',
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:text.bodySmall),
              ])),
              Icon(Icons.more_horiz_rounded,color:scheme.onSurfaceVariant),
            ]),
            const SizedBox(height:15),
            Text(post.title,maxLines:3,overflow:TextOverflow.ellipsis,
              style:text.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
            if(post.detail.isNotEmpty)...[
              const SizedBox(height:7),
              Text(post.detail,maxLines:3,overflow:TextOverflow.ellipsis),
            ],
            const SizedBox(height:14),
            Row(children:[
              Chip(label:Text(offer?'Offering help':'Needs help'),
                avatar:Icon(offer?Icons.favorite_border:
                  Icons.pan_tool_alt_outlined,size:15)),
              const SizedBox(width:7),
              Expanded(child:Text(post.category,textAlign:TextAlign.end,
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.labelSmall)),
            ]),
            Divider(color:scheme.outlineVariant),
            Row(children:[
              Icon(Icons.handshake_outlined,size:18,color:accent),
              const SizedBox(width:8),
              Text(owner?'Manage your Reach':'Connect with this member',
                style:text.labelLarge?.copyWith(
                  fontWeight:FontWeight.w800,color:scheme.primary)),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded,color:accent),
            ]),
          ]),
        )));
    }

    if(look.feed==ReachFeedLayout.timeline){
      // Alpine: a chronological people-first feed, with an explicit
      // timeline marker and editorial text rather than card mosaics.
      return InkWell(onTap:onTap,child:Padding(
        padding:const EdgeInsets.fromLTRB(4,12,4,13),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Column(children:[
            CircleAvatar(radius:19,
              child:Text(post.ownerName.isEmpty?'?':
                post.ownerName.characters.first.toUpperCase())),
            Container(width:2,height:94,
              margin:const EdgeInsets.only(top:7),
              color:scheme.outlineVariant),
          ]),
          const SizedBox(width:13),
          Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:Text(post.ownerName.isEmpty?'Member':post.ownerName,
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.titleSmall?.copyWith(fontWeight:FontWeight.w800))),
              Text(timeago.format(post.createdAt),style:text.labelSmall),
            ]),
            const SizedBox(height:5),
            Text(post.title,maxLines:2,overflow:TextOverflow.ellipsis,
              style:text.titleLarge?.copyWith(
                fontFamily:look.font,fontWeight:FontWeight.w700)),
            if(post.detail.isNotEmpty)...[
              const SizedBox(height:5),
              Text(post.detail,maxLines:2,overflow:TextOverflow.ellipsis),
            ],
            const SizedBox(height:8),
            Wrap(spacing:12,runSpacing:7,children:[
              miniTag(offer?Icons.favorite_outline:
                Icons.pan_tool_alt_outlined,offer?'Offer':'Request'),
              miniTag(Icons.location_on_outlined,post.city),
              miniTag(Icons.category_outlined,post.category),
            ]),
            const SizedBox(height:8),
            Text(owner?'Manage activity':'View and respond',
              style:text.labelSmall?.copyWith(
                color:scheme.primary,fontWeight:FontWeight.w800)),
          ])),
        ])));
    }

    if(look.feed==ReachFeedLayout.dashboard){
      // Blueprint: precision-oriented activity rows with bold category
      // identifiers and useful metadata in a compact two-level layout.
      return Card(margin:const EdgeInsets.only(bottom:7),
        child:InkWell(onTap:onTap,
          child:Padding(padding:const EdgeInsets.all(12),child:Row(
            crossAxisAlignment:CrossAxisAlignment.center,children:[
            Container(width:43,height:54,alignment:Alignment.center,
              decoration:BoxDecoration(
                border:Border.all(color:accent,width:1.3),
                borderRadius:BorderRadius.circular(4)),
              child:Icon(offer?Icons.handshake_outlined:
                Icons.help_outline,color:accent,size:23)),
            const SizedBox(width:12),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${offer?'OFFER':'REQUEST'} / ${post.category.toUpperCase()}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.labelSmall?.copyWith(
                  fontWeight:FontWeight.w900,color:scheme.primary,
                  letterSpacing:.6)),
              const SizedBox(height:3),
              Text(post.title,maxLines:2,overflow:TextOverflow.ellipsis,
                style:text.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
              const SizedBox(height:4),
              Text('${post.ownerName} · ${post.city} · ${timeago.format(post.createdAt)}',
                maxLines:1,overflow:TextOverflow.ellipsis,style:text.labelSmall),
            ])),
            const Icon(Icons.arrow_outward_rounded,size:20),
          ]))));
    }

    if(look.feed==ReachFeedLayout.compact){
      return Card(margin:const EdgeInsets.only(bottom:8),child:InkWell(
        onTap:onTap,customBorder:Theme.of(context).cardTheme.shape,
        child:Padding(padding:EdgeInsets.all(look.compact?9:12),
          child:Row(children:[
            Container(width:43,height:48,alignment:Alignment.center,
              decoration:BoxDecoration(color:accent.withValues(alpha:.13),
                borderRadius:BorderRadius.circular(look.radius.clamp(5.0,14.0).toDouble())),
              child:Icon(offer?Icons.volunteer_activism_outlined:
                Icons.pan_tool_alt_outlined,color:accent,size:23)),
            const SizedBox(width:12),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(post.title,maxLines:2,overflow:TextOverflow.ellipsis,
                style:text.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              Text(categoryLocation,maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.bodySmall),
              const SizedBox(height:3),
              Text('${post.ownerName} · ${timeago.format(post.createdAt)}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.labelSmall),
            ])),
            Icon(Icons.chevron_right_rounded,size:22,color:accent),
          ]))));
    }

    if(look.feed==ReachFeedLayout.editorial){
      return Card(margin:const EdgeInsets.only(bottom:12),child:InkWell(
        onTap:onTap,customBorder:Theme.of(context).cardTheme.shape,
        child:Padding(padding:EdgeInsets.all(look.compact?13:19),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Icon(offer?Icons.favorite_border:Icons.pan_tool_alt_outlined,
                size:17,color:accent),
              const SizedBox(width:7),
              Expanded(child:Text(status,
                style:text.labelSmall?.copyWith(
                  color:accent,fontWeight:FontWeight.w900,letterSpacing:1.2))),
              Text(timeago.format(post.createdAt),style:text.labelSmall),
            ]),
            const SizedBox(height:10),
            Text(post.title,maxLines:3,overflow:TextOverflow.ellipsis,
              style:text.titleLarge?.copyWith(
                fontFamily:look.font,fontWeight:FontWeight.w800)),
            if(post.detail.isNotEmpty)...[
              const SizedBox(height:7),
              Text(post.detail,maxLines:2,overflow:TextOverflow.ellipsis,
                style:text.bodyMedium),
            ],
            const SizedBox(height:12),
            Divider(color:scheme.outlineVariant),
            const SizedBox(height:6),
            Row(children:[
              Expanded(child:Text('${post.city} · ${post.category}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.labelSmall)),
              Text(action.toUpperCase(),style:text.labelSmall?.copyWith(
                color:accent,fontWeight:FontWeight.w900)),
              Icon(Icons.arrow_outward,size:17,color:accent),
            ]),
          ]))));
    }

    if(look.feed==ReachFeedLayout.bento){
      return Card(margin:const EdgeInsets.only(bottom:12),clipBehavior:Clip.antiAlias,
        child:InkWell(onTap:onTap,child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(
            height:57,width:double.infinity,
            padding:const EdgeInsets.symmetric(horizontal:15),
            decoration:BoxDecoration(
              gradient:LinearGradient(colors:[
                accent.withValues(alpha:.95),look.accent.withValues(alpha:.8)])),
            child:Row(children:[
              Icon(offer?Icons.volunteer_activism_outlined:
                Icons.pan_tool_alt_outlined,color:Colors.white,size:23),
              const SizedBox(width:9),
              Expanded(child:Text(status,style:const TextStyle(
                color:Colors.white,fontSize:11,fontWeight:FontWeight.w900,
                letterSpacing:1.1))),
              const Icon(Icons.arrow_outward,color:Colors.white,size:19),
            ]),
          ),
          Padding(padding:EdgeInsets.all(look.compact?12:16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(post.title,maxLines:2,overflow:TextOverflow.ellipsis,
                style:text.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
              if(post.detail.isNotEmpty)...[
                const SizedBox(height:6),
                Text(post.detail,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:text.bodyMedium),
              ],
              const SizedBox(height:13),
              Wrap(spacing:8,runSpacing:7,children:[
                miniTag(Icons.location_on_outlined,post.city),
                miniTag(Icons.category_outlined,post.category),
              ]),
              const SizedBox(height:10),
              Text('${post.ownerName} · ${timeago.format(post.createdAt)}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:text.labelSmall),
            ])),
        ])));
    }

    // Floating and accent-rail cards retain all metadata in a softer layout.
    final fg=offer?scheme.onSecondaryContainer:scheme.onTertiaryContainer;
    final background=offer?scheme.secondaryContainer:scheme.tertiaryContainer;
    final accentRail=look.feed==ReachFeedLayout.accent;
    return Card(margin:const EdgeInsets.only(bottom:12),
      child:InkWell(
        onTap:onTap,customBorder:Theme.of(context).cardTheme.shape,
        child:Container(
          decoration:accentRail?BoxDecoration(
            border:Border(left:BorderSide(color:accent,width:5))):null,
          child:Padding(padding:EdgeInsets.all(look.compact?12:17),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Container(padding:const EdgeInsets.symmetric(
                  horizontal:10,vertical:6),
                  decoration:BoxDecoration(
                    color:background,borderRadius:BorderRadius.circular(
                      accentRail?6:20)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    Icon(offer?Icons.volunteer_activism:
                      Icons.pan_tool_alt_outlined,color:fg,size:15),
                    const SizedBox(width:5),
                    Text(status,style:TextStyle(
                      color:fg,fontWeight:FontWeight.bold,fontSize:11)),
                  ])),
                const Spacer(),
                Text(timeago.format(post.createdAt),
                  style:text.bodySmall),
              ]),
              const SizedBox(height:11),
              Text(post.title,style:text.titleMedium?.copyWith(
                fontWeight:FontWeight.w900)),
              if(post.detail.isNotEmpty)...[
                const SizedBox(height:5),
                Text(post.detail,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:text.bodyMedium),
              ],
              const SizedBox(height:12),
              Wrap(spacing:8,runSpacing:8,children:[
                miniTag(Icons.category_outlined,post.category),
                miniTag(Icons.location_city_outlined,
                  '${post.city}, ${post.country}'),
                miniTag(Icons.schedule_rounded,
                  post.expired?'Expired':
                    'Until ${formatTime.format(post.expiresAt)}'),
                if(post.scope=='circle')
                  miniTag(Icons.lock_outline,post.circleName),
              ]),
              const SizedBox(height:12),
              Divider(height:1,color:scheme.outlineVariant),
              const SizedBox(height:10),
              Row(children:[
                CircleAvatar(radius:14,
                  child:Text(post.ownerName.isEmpty?'?':
                    post.ownerName.characters.first.toUpperCase(),
                    style:const TextStyle(fontSize:12))),
                const SizedBox(width:9),
                Expanded(child:Text(owner?'Your reach':post.ownerName,
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w600))),
                Text(owner?'Manage':'View & connect',
                  style:TextStyle(color:scheme.primary,
                    fontWeight:FontWeight.w800,fontSize:12)),
                Icon(Icons.chevron_right,color:scheme.primary),
              ]),
            ])),
        ),
      ),
    );
  }
}
Widget miniTag(IconData i,String s)=>Builder(builder:(context)=>Row(mainAxisSize:MainAxisSize.min,children:[
  Icon(i,size:14,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(width:4),
  Text(s,style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant))]));

Future<void> showReachDetail(BuildContext context,ReachPost post,{VoidCallback? onChanged}) async {
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
  builder:(sheet)=>Padding(padding:EdgeInsets.fromLTRB(22,6,22,MediaQuery.viewInsetsOf(sheet).bottom+28),
  child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
    Row(children:[Expanded(child:Text(post.kind=='offer'?'Offering help':'Looking for help',
      style:Theme.of(sheet).textTheme.labelLarge)),
      if(reach.uid!=post.ownerId)PopupMenuButton<String>(tooltip:'Safety',onSelected:(v)async {
        if(v=='report')await showReportDialog(sheet,'post',post.id);
        if(v=='block')await confirmBlock(sheet,post.ownerId,post.ownerName);
      },itemBuilder:(_)=>const [PopupMenuItem(value:'report',child:Text('Report this post')),
        PopupMenuItem(value:'block',child:Text('Block this member'))]),
    ]),gap(8),Text(post.title,style:Theme.of(sheet).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
    gap(8),Text(post.detail.isEmpty?'No additional details provided.':post.detail),gap(16),
    Wrap(spacing:14,runSpacing:10,children:[miniTag(Icons.person_outline,post.ownerName),
      miniTag(Icons.location_on_outlined,'${post.city}, ${post.country}'),
      miniTag(Icons.schedule,'Ends ${formatTime.format(post.expiresAt)}')]),gap(20),
    if(reach.uid==post.ownerId)
      OutlinedButton.icon(onPressed:()=>busy(sheet,()async {await reach.closePost(post.id);
          popSafe(sheet);onChanged?.call();},success:'Availability closed'),
        icon:const Icon(Icons.check_circle_outline),label:const Text('Close this reach'))
    else if(!post.expired)
      FilledButton.icon(onPressed:()async{
        popSafe(sheet);
        final m=await askText(context,title:'Introduce yourself',hint:'How can you connect or help?',maxLines:3);
        if(m!=null&&m.trim().length>=2)await busy(context,()=>reach.request(post.id,m.trim()),
          success:'Request sent. The other person can accept or decline.');
      },icon:const Icon(Icons.handshake_outlined),label:const Padding(padding:EdgeInsets.all(12),child:Text('Request to connect')))
    else const Text('This availability window has ended.'),
  ]))));
}

Future<String?> askText(BuildContext context,{required String title,required String hint,int maxLines=1}) async {
 final controller=TextEditingController();
 final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),
  content:TextField(controller:controller,maxLines:maxLines,maxLength:maxLines==1?70:400,
    autofocus:true,decoration:InputDecoration(hintText:hint)),actions:[
   TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Continue')),
  ]));controller.dispose();return value;
}
Future<void> confirmBlock(BuildContext context,String id,String name) async {
 final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
   title:Text('Block $name?'),content:const Text('You will no longer see each other’s posts or conversations.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
     FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Block'))]));
 if(confirmed==true && context.mounted) await busy(context,()=>reach.blockUser(id),success:'Member blocked');
}
Future<void> showReportDialog(BuildContext context,String type,String id) async {
 String reason='spam';final note=TextEditingController();
 final shouldReport=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
  builder:(ctx,setLocal)=>AlertDialog(title:const Text('Report a concern'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(initialValue:reason,items:const [
        DropdownMenuItem(value:'spam',child:Text('Spam')),
        DropdownMenuItem(value:'harassment',child:Text('Harassment')),
        DropdownMenuItem(value:'unsafe',child:Text('Unsafe content')),
        DropdownMenuItem(value:'child_safety',child:Text('Child safety / exploitation')),
        DropdownMenuItem(value:'sexual_exploitation',child:Text('Sexual exploitation')),
        DropdownMenuItem(value:'adult_content',child:Text('Pornography / sexual content')),
        DropdownMenuItem(value:'illegal_content',child:Text('Illegal content or trade')),
        DropdownMenuItem(value:'dangerous_activities',child:Text('Dangerous activities')),
        DropdownMenuItem(value:'self_harm',child:Text('Self-harm promotion')),
        DropdownMenuItem(value:'fraud',child:Text('Fraud / impersonation')),
        DropdownMenuItem(value:'impersonation',child:Text('Impersonation')),
        DropdownMenuItem(value:'other',child:Text('Other'))],
        onChanged:(v)=>setLocal(()=>reason=v??reason)),gap(12),
      TextField(controller:note,maxLines:3,maxLength:1000,decoration:const InputDecoration(labelText:'Details (optional)'))]),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Submit report'))])));
 final text=note.text;note.dispose();
 if(shouldReport==true && context.mounted)await busy(context,()=>reach.report(type,id,reason,text),
   success:'Report received for moderation review.');
}

class MinePage extends StatefulWidget{const MinePage({super.key,required this.onCreated});final VoidCallback onCreated;
 @override State<MinePage> createState()=>_MinePageState();}
class _MinePageState extends State<MinePage>{
 List<ReachPost> posts=[];bool loading=true;
 @override void initState(){super.initState();refresh();}
 Future<void> refresh() async {
  final p=await busy(context,reach.myPosts);
  if(mounted)setState((){if(p!=null)posts=p;loading=false;});
 }
 @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:RefreshIndicator(onRefresh:refresh,
  child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,90),children:[
   sectionHeader(context,'My Reach',subtitle:'Offer your time or ask your community',
     trailing:IconButton(icon:const Icon(Icons.refresh),onPressed:refresh)),
   Row(children:[Expanded(child:_quickAction(context,Icons.favorite_outline,'Offer help',()=>compose('offer'))),
     const SizedBox(width:12),Expanded(child:_quickAction(context,Icons.pan_tool_alt_outlined,'Ask for help',()=>compose('request')))]),gap(20),
   Text('Your availability',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),gap(10),
   if(loading)const Center(child:CircularProgressIndicator())
   else if(posts.isEmpty)emptyState(context,Icons.bolt_outlined,'No reaches yet','Start by offering a skill or asking for help.')
   else ...posts.map((p)=>ReachCard(post:p,owner:true,onTap:()=>showReachDetail(context,p,onChanged:refresh))),
  ]))),floatingActionButton:FloatingActionButton.extended(onPressed:()=>compose('offer'),
    icon:const Icon(Icons.add),label:const Text('New reach')));
 Widget _quickAction(BuildContext c,IconData i,String label,VoidCallback onTap)=>Card(child:InkWell(
    customBorder:Theme.of(c).cardTheme.shape,onTap:onTap,child:Padding(padding:const EdgeInsets.all(20),
      child:Column(children:[Icon(i,size:32,color:Theme.of(c).colorScheme.primary),gap(9),
       Text(label,style:const TextStyle(fontWeight:FontWeight.bold))]))));
 Future<void> compose(String type) async {
   final success=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ComposePage(initialType:type)));
   if(success==true){await refresh();widget.onCreated();}
 }
}

class ComposePage extends StatefulWidget {
 const ComposePage({super.key,this.initialType='offer',this.initialCircleId});
 final String initialType;
 final String? initialCircleId;
 @override State<ComposePage> createState()=>_ComposePageState();
}
class _ComposePageState extends State<ComposePage>{
 final title=TextEditingController(),detail=TextEditingController();
 String type='offer',category='Technology',duration='1 hour',circleId='public';
 List<Map<String,dynamic>> circles=[];bool saving=false;
 final durations={'30 minutes':const Duration(minutes:30),'1 hour':const Duration(hours:1),
   '3 hours':const Duration(hours:3),'Today':const Duration(hours:24),'7 days':const Duration(days:7)};
 @override void initState(){
   super.initState();
   type=widget.initialType;
   circleId=widget.initialCircleId??'public';
   load();
 }
 Future<void> load()async {
   final c=await busy(context,reach.circles);
   if(mounted&&c!=null)setState((){
     circles=c;
     if(circleId!='public'&&!circles.any((m)=>str(m['id'])==circleId)){
       circleId='public';
     }
   });
 }
 @override void dispose(){title.dispose();detail.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Create a Reach')),
  body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
   Text('What would you like to do?',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
   gap(6),const Text('Make a small offer or request. Others can connect only if you approve.'),gap(20),
   SegmentedButton<String>(segments:const [ButtonSegment(value:'offer',label:Text('I can help'),icon:Icon(Icons.favorite_outline)),
    ButtonSegment(value:'request',label:Text('I need help'),icon:Icon(Icons.pan_tool_alt))],
    selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first)),gap(20),
   TextField(controller:title,maxLength:110,textCapitalization:TextCapitalization.sentences,
    decoration:InputDecoration(labelText:'Short headline',hintText:type=='offer'?'I can help with an Excel formula':'Need quick help understanding a topic')),
   gap(12),TextField(controller:detail,maxLength:1500,maxLines:4,textCapitalization:TextCapitalization.sentences,
     decoration:const InputDecoration(labelText:'Details',hintText:'Explain the task, availability and expectations. No phone numbers or exact addresses.')),
   gap(12),DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Category'),
     items:categories.where((x)=>x!='All').map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
     onChanged:(v)=>setState(()=>category=v??category)),gap(12),
   DropdownButtonFormField<String>(initialValue:duration,decoration:const InputDecoration(labelText:'Available for'),
     items:durations.keys.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
     onChanged:(v)=>setState(()=>duration=v??duration)),gap(12),
   DropdownButtonFormField<String>(key:ValueKey('circle-$circleId-${circles.length}'),
     initialValue:(circleId=='public'||circles.any((c)=>str(c['id'])==circleId))?circleId:'public',decoration:const InputDecoration(labelText:'Visible to'),
     items:[const DropdownMenuItem(value:'public',child:Text('Everyone in selected discovery area')),
       ...circles.map((c)=>DropdownMenuItem(value:str(c['id']),child:Text('Circle: ${c['name']}')))],
     onChanged:(v)=>setState(()=>circleId=v??'public')),gap(12),
   Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[const Icon(Icons.shield_outlined),
     const SizedBox(width:10),Expanded(child:Text('Your contact information remains private. Only accepted requests open a chat.',
       style:Theme.of(context).textTheme.bodySmall))]))),gap(20),
   FilledButton.icon(onPressed:saving?null:()async{
      if(title.text.trim().length<8){ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Enter a headline of at least 8 characters.')));return;}
      setState(()=>saving=true);
      final ok=await busy(context,() async {
        await reach.createPost(kind:type,title:title.text,detail:detail.text,
          category:category,duration:durations[duration]!,
          circleId:circleId=='public'?null:circleId);
        return true;
      },success:'Reach published!');
      if(mounted){setState(()=>saving=false);
        // createPost returns void; success is tracked through the separate bool below.
      }
      if(ok==true && context.mounted) Navigator.pop(context,true);
   },icon:const Icon(Icons.rocket_launch_outlined),label:Padding(padding:const EdgeInsets.all(13),
    child:Text(saving?'Publishing…':'Publish my Reach'))),
  ])));
}

class InboxPage extends StatefulWidget{const InboxPage({super.key});@override State<InboxPage> createState()=>_InboxPageState();}
class _InboxPageState extends State<InboxPage>{
 int tab=0;
 bool loading=true;
 int loadSerial=0;
 String? loadError;
 List<ReachRequest> incoming=[],outgoing=[];
 List<Map<String,dynamic>> conversations=[],alerts=[],memberRequests=[];

 @override void initState(){super.initState();unawaited(refresh());}

 /// Fetch only the visible tab. Never display an old Inbox RPC timeout
 /// as an unrelated popup over the member's privacy settings.
 Future<void> refresh() async {
   final serial=++loadSerial;
   final requestedTab=tab;
   if(!mounted)return;
   setState((){loading=true;loadError=null;});
   try{
     if(requestedTab==0){
       final value=await reach.conversations()
         .timeout(const Duration(seconds:18));
       if(mounted&&serial==loadSerial)setState(()=>conversations=value);
     }else if(requestedTab==1){
       final values=await Future.wait<Object?>([
         reach.requests().timeout(const Duration(seconds:18)),
         reach.requests(incoming:false).timeout(const Duration(seconds:18)),
         reach.memberRequests().timeout(const Duration(seconds:18)),
       ]);
       if(mounted&&serial==loadSerial)setState((){
         incoming=values[0] as List<ReachRequest>;
         outgoing=values[1] as List<ReachRequest>;
         memberRequests=values[2] as List<Map<String,dynamic>>;
       });
     }else{
       final value=await reach.alerts().timeout(const Duration(seconds:18));
       if(mounted&&serial==loadSerial)setState(()=>alerts=value);
     }
   }catch(e){
     if(mounted&&serial==loadSerial)setState(()=>loadError=humanError(e));
   }finally{
     if(mounted&&serial==loadSerial)setState(()=>loading=false);
   }
 }
 @override Widget build(BuildContext context)=>SafeArea(child:Column(children:[
  Padding(padding:const EdgeInsets.fromLTRB(14,12,14,8),
    child:ReachExperienceHeader(title:'Chats',
      subtitle:'Direct messages, invitations and alerts',
      icon:Icons.forum_outlined,
      actions:IconButton(tooltip:'Refresh chats and activity',
        onPressed:refresh,icon:const Icon(Icons.refresh_rounded)))),
  Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:SegmentedButton<int>(
    segments:const [ButtonSegment(value:0,label:Text('Direct')),ButtonSegment(value:1,label:Text('Requests')),
      ButtonSegment(value:2,label:Text('Alerts'))],selected:{tab},
    onSelectionChanged:(v){
       setState(()=>tab=v.first);
       unawaited(refresh());
       if(tab==2)unawaited(markAlertsRead());
     })),gap(10),
  if(loadError!=null)Padding(
    padding:const EdgeInsets.fromLTRB(18,4,18,8),
    child:Row(children:[
      Icon(Icons.wifi_off_outlined,color:Theme.of(context).colorScheme.error),
      const SizedBox(width:9),
      Expanded(child:Text(loadError!,
        style:Theme.of(context).textTheme.bodySmall)),
      TextButton(onPressed:()=>unawaited(refresh()),child:const Text('Retry')),
    ])),
  Expanded(child:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,
    child:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,40),children:tab==0?_chatRows():tab==1?_requestRows():_alertRows()))),
 ]));
 Future<void> markAlertsRead() async {
   await busy(context,reach.readAlerts);
   if(mounted)await refresh();
 }
 List<Widget> _chatRows(){
  if(conversations.isEmpty)return [gap(80),emptyState(context,Icons.forum_outlined,'No conversations yet',
    'When someone accepts a request, your private chat appears here.')];
  return conversations.map((c)=>Card(child:ListTile(
   leading:const CircleAvatar(child:Icon(Icons.person_outline)),
   title:Text(str(c['peer_name']),style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:Text('${c['post_title']}\n${str(c['last_body'])}',maxLines:2,overflow:TextOverflow.ellipsis),
   isThreeLine:true,trailing:const Icon(Icons.chevron_right),
   onTap:()async {await Navigator.push(context,MaterialPageRoute(
     builder:(_)=>ChatPage(conversationId:str(c['id']),peerId:str(c['peer_id']),
       peerName:str(c['peer_name']),topic:str(c['post_title']))));if(mounted)refresh();},
   ))).toList();
 }
 List<Widget> _requestRows(){
   if(incoming.isEmpty&&outgoing.isEmpty&&memberRequests.isEmpty)return [
     gap(80),emptyState(context,Icons.handshake_outlined,'No requests',
       'Find people or respond to an offer to start a private connection.')];
   final receivedMembers=memberRequests.where((m)=>m['incoming']==true).toList();
   final sentMembers=memberRequests.where((m)=>m['incoming']!=true).toList();
   return [
     if(receivedMembers.isNotEmpty)...[
       Text('People who requested to connect',
         style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
       gap(8),
       ...receivedMembers.map((m)=>Card(child:Padding(padding:const EdgeInsets.all(14),
         child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text(str(m['peer_name']),style:const TextStyle(fontWeight:FontWeight.bold)),
           if(str(m['peer_username']).isNotEmpty)Text('@${m['peer_username']}'),
           gap(6),Text(str(m['message'])),gap(9),
           if(m['status']=='pending')Wrap(spacing:8,children:[
             FilledButton.tonal(onPressed:()=>busy(context,()async{
               await reach.answerMember(str(m['id']),true);await refresh();
             },success:'Connected. Find this member under Chats.'),
               child:const Text('Accept')),
             OutlinedButton(onPressed:()=>busy(context,()async{
               await reach.answerMember(str(m['id']),false);await refresh();
             },success:'Request declined'),child:const Text('Decline')),
           ]) else Text(str(m['status']).toUpperCase()),
         ])))),
       gap(13),
     ],
     if(sentMembers.isNotEmpty)...[
       Text('People you contacted',
         style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
       gap(8),
       ...sentMembers.map((m)=>Card(child:ListTile(
         title:Text(str(m['peer_name'])),subtitle:Text(str(m['message'])),
         trailing:Chip(label:Text(str(m['status'])))))),
       gap(13),
     ],
     if(incoming.isNotEmpty)...[Text('Received',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),gap(8)],
    ...incoming.map((r)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(r.senderName,style:const TextStyle(fontWeight:FontWeight.bold)),Text('About: ${r.postTitle}',
        style:Theme.of(context).textTheme.bodySmall),gap(5),Text(r.message),gap(8),
       if(r.status=='pending')Wrap(spacing:8,children:[
          FilledButton.tonal(onPressed:()=>busy(context,()async{
            await reach.answerRequest(r.id,true);await refresh();},success:'Connection accepted'),child:const Text('Accept')),
          OutlinedButton(onPressed:()=>busy(context,()async{
            await reach.answerRequest(r.id,false);await refresh();},success:'Request declined'),child:const Text('Decline'))])
       else Text(r.status.toUpperCase(),style:Theme.of(context).textTheme.labelSmall),
     ])))),
    if(outgoing.isNotEmpty)...[gap(14),Text('Sent',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),gap(8)],
    ...outgoing.map((r)=>Card(child:ListTile(title:Text(r.postTitle),subtitle:Text(r.message),
      trailing:Chip(label:Text(r.status))))),
   ];
 }
 List<Widget> _alertRows(){
  if(alerts.isEmpty)return [gap(80),emptyState(context,Icons.notifications_none,'All caught up',
    'Your connection requests, acceptances and messages appear here while the app is in use.')];
  return alerts.map((a)=>Card(child:ListTile(leading:Icon(a['read_at']==null?
    Icons.notifications_active_outlined:Icons.notifications_none),
    title:Text(str(a['title'])),subtitle:Text(str(a['body'])),
    trailing:Text(timeago.format(dateOf(a['created_at'])),style:Theme.of(context).textTheme.bodySmall)))).toList();
 }
}

class ChatPage extends StatefulWidget {
 const ChatPage({super.key,required this.conversationId,required this.peerId,
  required this.peerName,required this.topic});
 final String conversationId,peerId,peerName,topic;
 @override State<ChatPage> createState()=>_ChatPageState();
}
class _ChatPageState extends State<ChatPage>{
 final text=TextEditingController();bool sending=false;
 Future<bool>? canCall;
 @override void initState(){super.initState();if(AppConfig.callingEnabled)canCall=reach.canCall(widget.peerId);}
 @override void dispose(){text.dispose();super.dispose();}
 Future<void> send()async{
  final message=text.text.trim();if(message.isEmpty||message.length>2000||sending)return;
  setState(()=>sending=true);
  final sent=await busy(context,()async{await reach.sendMessage(widget.conversationId,message);return true;});
  if(mounted){if(sent==true)text.clear();setState(()=>sending=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(
   title:Row(children:[
     ReachMemberAvatar(memberId:widget.peerId,name:widget.peerName,size:37),
     const SizedBox(width:9),
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(widget.peerName,maxLines:1,overflow:TextOverflow.ellipsis),
       Text(widget.topic,style:Theme.of(context).textTheme.bodySmall,
         maxLines:1,overflow:TextOverflow.ellipsis),
     ])),
   ]),
   actions:[
     if(AppConfig.callingEnabled)IconButton(
       tooltip:'Recheck calling consent',
       onPressed:()=>setState(()=>canCall=reach.canCall(widget.peerId)),
       icon:const Icon(Icons.refresh_rounded)),
     PopupMenuButton<String>(onSelected:(v)async{
       if(v=='block'){await confirmBlock(context,widget.peerId,widget.peerName);if(context.mounted)Navigator.pop(context);}
       if(v=='report') await showReportDialog(context,'user',widget.peerId);
     },itemBuilder:(_)=>const [PopupMenuItem(value:'report',child:Text('Report member')),
        PopupMenuItem(value:'block',child:Text('Block member'))])]),
   body:SafeArea(child:Column(children:[
    Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(stream:reach.messages(widget.conversationId),
     builder:(context,snap){
      if(snap.hasError)return emptyState(context,Icons.error_outline,'Chat unavailable',humanError(snap.error!));
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final data=snap.data!;
      if(data.isEmpty)return emptyState(context,Icons.chat_bubble_outline,'Say hello','Your conversation is private to the two participants.');
      return ListView.builder(reverse:true,padding:const EdgeInsets.all(14),itemCount:data.length,
       itemBuilder:(c,index){final m=data[data.length-1-index];final mine=m['sender_id']==reach.uid;
        return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:ConstrainedBox(
         constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(c).width*.78),
         child:Container(margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.all(13),
          decoration:BoxDecoration(
            color:mine?Theme.of(c).colorScheme.primaryContainer:
              Theme.of(c).colorScheme.surfaceContainerHigh,
            borderRadius:BorderRadius.only(
              topLeft:Radius.circular(ReachDesign.of(c).radius),
              topRight:Radius.circular(ReachDesign.of(c).radius),
              bottomLeft:Radius.circular(mine?ReachDesign.of(c).radius:5),
              bottomRight:Radius.circular(mine?5:ReachDesign.of(c).radius)),
            border:ReachDesign.of(c).outlined?Border.all(
              color:Theme.of(c).colorScheme.outlineVariant):null),
          child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
            Text(str(m['body'])),gap(5),
            Row(mainAxisSize:MainAxisSize.min,children:[
              Text(DateFormat('h:mm a').format(dateOf(m['created_at'])),
               style:Theme.of(c).textTheme.labelSmall),
              IconButton(onPressed:()=>showReportDialog(context,'message',str(m['id'])),
                icon:const Icon(Icons.flag_outlined,size:14),tooltip:'Report message',visualDensity:VisualDensity.compact,
                constraints:const BoxConstraints(minWidth:24,minHeight:24))]),
          ]))));
       });
     })),
    if(AppConfig.callingEnabled)FutureBuilder<bool>(
      future:canCall,builder:(context,snapshot){
        if(snapshot.data==true)return ReachCallActions(
          conversationId:widget.conversationId,peerId:widget.peerId,
          peerName:widget.peerName);
        return Padding(padding:const EdgeInsets.symmetric(vertical:8,horizontal:16),
          child:Text(snapshot.hasError?'Call availability could not be verified.':
            'Calling requires both members to opt in under Me → Privacy & calling.',
            textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.bodySmall));
      }),
    ChatAttachmentsPanel(conversationId:widget.conversationId),
    Container(padding:const EdgeInsets.fromLTRB(12,8,8,9),decoration:BoxDecoration(
      color:Theme.of(context).colorScheme.surface),
     child:Row(children:[Expanded(child:TextField(controller:text,maxLength:2000,minLines:1,maxLines:4,
       textCapitalization:TextCapitalization.sentences,
       decoration:const InputDecoration(hintText:'Write a message',counterText:'',border:InputBorder.none))),
       IconButton(onPressed:sending?null:send,icon:const Icon(Icons.send_rounded),tooltip:'Send')]))
   ])));
}

class CirclesPage extends StatefulWidget {
 const CirclesPage({super.key});
 @override State<CirclesPage> createState()=>_CirclesPageState();
}
class _CirclesPageState extends State<CirclesPage> {
 bool loading=true;
 String area='country',topic='All';
 List<Map<String,dynamic>> circles=[],publicGroups=[];
 final search=TextEditingController();
 Timer? searchDebounce;
 int requestSerial=0;

 @override void initState(){super.initState();refresh();}
 @override void dispose(){
   searchDebounce?.cancel();
   search.dispose();
   super.dispose();
 }
 Future<void> refresh() async {
   final ticket=++requestSerial;
   if(mounted)setState(()=>loading=true);
   final data=await busy(context,() async => <String,dynamic>{
     'mine': await reach.circles(),
     'public': await reach.discoverCommunities(
        area:area,category:topic,keyword:search.text),
   });
   if(mounted && ticket==requestSerial) {
     setState(() {
       if(data!=null) {
         circles=(data['mine'] as List).cast<Map<String,dynamic>>();
         publicGroups=(data['public'] as List).cast<Map<String,dynamic>>();
       }
       loading=false;
     });
   }
 }

 Future<void> createGroup({CommunityTemplate? template}) async {
   final name=TextEditingController(text:template?.name??'');
   final description=TextEditingController(text:template?.description??'');
   final form=GlobalKey<FormState>();
   String category=template?.category??'Community & volunteering';
   bool isPublic=true;
   final result=await showDialog<Map<String,dynamic>>(
     context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
       title:Text(template==null?'Create a group':'Start ${template.name}'),
       content:SizedBox(width:430,child:Form(key:form,child:SingleChildScrollView(
         child:Column(mainAxisSize:MainAxisSize.min,children:[
           gap(7),
           TextFormField(controller:name,maxLength:70,
             textCapitalization:TextCapitalization.words,
             decoration:const InputDecoration(labelText:'Group name'),
             validator:(v)=>((v??'').trim().length<3)
                ?'Use at least 3 characters':null),
           TextFormField(controller:description,maxLength:240,maxLines:3,
             decoration:const InputDecoration(labelText:'What is this group for?')),
           DropdownButtonFormField<String>(isExpanded:true,initialValue:category,
             decoration:const InputDecoration(labelText:'Activity / topic'),
             items:categories.where((x)=>x!='All').map((x)=>
               DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
             onChanged:(v)=>change(()=>category=v??category)),
           SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
             title:Text(isPublic?'Public group':'Private invitation circle'),
             subtitle:Text(isPublic
                 ?'Members can find and join. Group posts remain member-only.'
                 :'Only people with your invite code can join.'),
             value:isPublic,onChanged:(v)=>change(()=>isPublic=v)),
         ])))),
       actions:[
         TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
         FilledButton(onPressed:(){
           if(!form.currentState!.validate())return;
           Navigator.pop(ctx,{
             'name':name.text.trim(),'description':description.text.trim(),
             'category':category,'public':isPublic
           });
         },child:const Text('Create group'))
       ],
     )));
   name.dispose();description.dispose();
   if(result==null||!mounted)return;
   await busy(context,()async{
     await reach.createCommunity(
       name:result['name'] as String,category:result['category'] as String,
       description:result['description'] as String,
       isPublic:result['public'] as bool);
     await refresh();
   },success:'Group created. You are its owner and first member.');
   if(mounted&&circles.isNotEmpty)unawaited(openGroup(circles.first));
 }
 Future<void> joinInvite() async {
   final code=await askText(context,title:'Join a private circle',
      hint:'Enter its invitation code');
   if(code!=null&&code.isNotEmpty&&mounted){
     await busy(context,()async{
       await reach.joinCircle(code);
       await refresh();
     },success:'Invitation accepted. Welcome to the group.');
     if(mounted){
       final m=circles.where((c)=>str(c['invite_code'])==code.trim().toUpperCase());
       if(m.isNotEmpty)unawaited(openGroup(m.first));
     }
   }
 }
 Future<void> joinPublic(String id) async {
   await busy(context,()async{
     await reach.joinPublicCommunity(id);
     await refresh();
   },success:'Joined. Explore discussions and resources in the group.');
   if(mounted){
     final m=circles.where((c)=>str(c['id'])==id);
     if(m.isNotEmpty)unawaited(openGroup(m.first));
   }
 }
 Future<void> openGroup(Map<String,dynamic> group) async {
   await Navigator.push(context,MaterialPageRoute(builder:(_)=>ReachGroupWorkspace(
     group:group,
     onCompose:(id)async{
       await Navigator.push<bool>(context,MaterialPageRoute(
         builder:(_)=>ComposePage(initialCircleId:id)));
     },
     onOpenReach:(post)async{
       await showReachDetail(context,post,onChanged:refresh);
     },
   )));
   if(mounted)await refresh();
 }
 Future<void> leaveOrDelete(Map<String,dynamic> c) async {
   final owner=c['owner_id']==reach.uid;
   final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
     AlertDialog(
       title:Text(owner?'Delete this group?':'Leave this group?'),
       content:Text(owner
         ?'Deleting also removes group posts and related conversations. This cannot be undone.'
         :'You can rejoin a public group later, or use a private invite code.'),
       actions:[
         TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
         FilledButton(onPressed:()=>Navigator.pop(ctx,true),
           child:Text(owner?'Delete':'Leave'))
       ],
     ));
   if(confirmed!=true||!mounted)return;
   await busy(context,()async{
     if(owner){await reach.deleteCircle(str(c['id']));}
     else {await reach.leaveCircle(str(c['id']));}
     await refresh();
   },success:owner?'Group deleted':'Left the group');
 }

 Widget publicCard(Map<String,dynamic> g){
   final member=g['is_member']==true,owner=g['owner_id']==reach.uid;
   final id=str(g['id']);
   return Card(margin:const EdgeInsets.symmetric(vertical:5),
     child:Padding(padding:const EdgeInsets.all(14),child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,children:[
         Row(children:[
           CircleAvatar(child:Icon(Icons.groups_rounded,
             color:Theme.of(context).colorScheme.onPrimaryContainer)),
           const SizedBox(width:12),
           Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
             children:[
               Text(str(g['name']),maxLines:2,overflow:TextOverflow.ellipsis,
                 style:Theme.of(context).textTheme.titleMedium?.copyWith(
                   fontWeight:FontWeight.w800)),
               Text('${g['category']} · ${g['member_count']} members',
                 style:Theme.of(context).textTheme.bodySmall),
             ])),
           if(!owner)PopupMenuButton<String>(
             tooltip:'Group safety',
             onSelected:(v) async {
               if(v=='report')await showReportDialog(context,'group',id);
               if(v=='block')await confirmBlock(context,str(g['owner_id']),
                 'this group owner');
               if(mounted)refresh();
             },itemBuilder:(_)=>const [
               PopupMenuItem(value:'report',child:Text('Report this group')),
               PopupMenuItem(value:'block',child:Text('Block group owner'))
             ]),
         ]),
         if(str(g['description']).isNotEmpty)...[
           gap(9),Text(str(g['description']),maxLines:3,
              overflow:TextOverflow.ellipsis)],
         gap(11),
         Row(children:[
           Expanded(child:Text('${g['city']}, ${g['country']}',
             maxLines:1,overflow:TextOverflow.ellipsis,
             style:Theme.of(context).textTheme.bodySmall)),
           member?FilledButton.tonalIcon(
               onPressed:()async{
                 final m=circles.where((c)=>str(c['id'])==id);
                 if(m.isNotEmpty)await openGroup(m.first);
                 else await refresh();
               },icon:const Icon(Icons.arrow_forward_rounded),
               label:const Text('Open'))
             :FilledButton.icon(onPressed:()=>joinPublic(id),
               icon:const Icon(Icons.group_add_outlined),
               label:const Text('Join'))
         ])
       ])));
 }

 Widget privateOrJoinedCard(Map<String,dynamic> c){
   final owner=c['owner_id']==reach.uid;
   final isPublic=c['visibility']=='public';
   final name=str(c['name']);
   return Card(margin:const EdgeInsets.symmetric(vertical:5),
     child:Padding(padding:const EdgeInsets.all(13),child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,children:[
         Row(children:[
           CircleAvatar(child:Icon(isPublic
             ?Icons.public_rounded:Icons.lock_outline)),
           const SizedBox(width:10),
           Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
             children:[
               Text(name,style:Theme.of(context).textTheme.titleMedium?.copyWith(
                 fontWeight:FontWeight.w800)),
               Text('${c['category']} · ${c['member_count']} members · '
                 '${owner?'Owner':'Member'}',
                 style:Theme.of(context).textTheme.bodySmall)
             ])),
           IconButton(tooltip:'Open group workspace',
             onPressed:()=>openGroup(c),icon:const Icon(Icons.open_in_new_rounded)),
           PopupMenuButton<String>(tooltip:'Group actions',
             onSelected:(v)async{
               if(v=='share')await SharePlus.instance.share(ShareParams(
                 text:'Join my Reach group "$name". Code: ${c['invite_code']}. '
                   'Open Reach → Groups → Join by code.'));
               if(v=='add'){
                 await Navigator.push(context,MaterialPageRoute(builder:(_)=>
                   ReachGroupAddMemberPage(
                     circleId:str(c['id']),groupName:name)));
                 if(mounted)await refresh();
               }
               if(v=='leave')await leaveOrDelete(c);
             },
             itemBuilder:(_)=>[
               if(owner)const PopupMenuItem(value:'add',
                 child:Text('Add members')),
               const PopupMenuItem(value:'share',
                 child:Text('Share invitation code')),
               PopupMenuItem(value:'leave',
                 child:Text(owner?'Delete group':'Leave group')),
             ]),
         ]),
         if(str(c['description']).isNotEmpty)...[
           gap(6),Text(str(c['description']),
             style:Theme.of(context).textTheme.bodyMedium)],
         gap(8),
         if(isPublic)const Text('Public group · member-only discussions and resources',
             style:TextStyle(fontSize:12)),
         Row(children:[
           Expanded(child:SelectableText('Invite code: ${c['invite_code']}',
             style:Theme.of(context).textTheme.bodySmall)),
           IconButton(tooltip:'Share invite code',icon:const Icon(Icons.share_outlined),
             onPressed:()=>SharePlus.instance.share(ShareParams(
               text:'Join my private Reach circle “$name”. Code: ${c['invite_code']}'))),
         ]),
         const SizedBox(height:10),
         SizedBox(width:double.infinity,child:FilledButton.tonalIcon(
           onPressed:()=>openGroup(c),icon:const Icon(Icons.groups_rounded),
           label:const Text('Open group workspace'))),
       ])));
 }

 @override Widget build(BuildContext context)=>SafeArea(
   child:RefreshIndicator(onRefresh:refresh,child:ListView(
     padding:const EdgeInsets.fromLTRB(18,16,18,42),children:[
       ReachExperienceHeader(title:'Groups',subtitle:'Communities, invitations and shared spaces',icon:Icons.groups_rounded),
       gap(9),
       Row(children:[
         Expanded(child:FilledButton.icon(onPressed:()=>createGroup(),
            icon:const Icon(Icons.add_circle_outline),label:const Text('Create group'))),
         const SizedBox(width:8),
         Expanded(child:OutlinedButton.icon(onPressed:joinInvite,
            icon:const Icon(Icons.key_outlined),label:const Text('Join by code')))
       ]),
       gap(12),
       ReachGroupInvitations(onJoined:()=>unawaited(refresh())),
       sectionHeader(context,'Your groups',
         subtitle:'Open discussions, group resources and members'),
       gap(10),
       if(!loading && circles.isEmpty)Card(child:Padding(
         padding:const EdgeInsets.all(18),
         child:const Text('No groups joined yet. Create one above or join '
             'a trusted circle by invitation code.')))
       else if(!loading)...circles.map(privateOrJoinedCard),
       gap(18),
       sectionHeader(context,'Start with a group idea',
         subtitle:'Templates only · groups exist when someone creates them'),
       gap(8),
       SizedBox(height:156,child:ListView.separated(
         scrollDirection:Axis.horizontal,
         itemCount:communityTemplates.length,
         separatorBuilder:(_,__)=>const SizedBox(width:10),
         itemBuilder:(ctx,i){
           final t=communityTemplates[i];
           return SizedBox(width:205,child:Card(
             child:InkWell(
               borderRadius:BorderRadius.circular(14),
               onTap:()=>createGroup(template:t),
               child:Padding(padding:const EdgeInsets.all(13),
                 child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                   children:[
                     Icon(t.icon,size:25,color:Theme.of(ctx).colorScheme.primary),
                     gap(8),
                     Text(t.name,maxLines:1,overflow:TextOverflow.ellipsis,
                       style:Theme.of(ctx).textTheme.titleSmall?.copyWith(
                         fontWeight:FontWeight.bold)),
                     gap(5),
                     Expanded(child:Text(t.description,maxLines:2,
                       overflow:TextOverflow.ellipsis,
                       style:Theme.of(ctx).textTheme.bodySmall)),
                     Text('Start this group',
                       style:TextStyle(color:Theme.of(ctx).colorScheme.primary,
                         fontWeight:FontWeight.w700,fontSize:12)),
                   ])))),
           );
         })),
       gap(21),
       sectionHeader(context,'Explore public groups'),
       gap(8),
       TextField(controller:search,
         onChanged:(_){
           searchDebounce?.cancel();
           searchDebounce=Timer(const Duration(milliseconds:450),refresh);
         },
         decoration:const InputDecoration(
           hintText:'Search public groups',
           prefixIcon:Icon(Icons.search_rounded))),
       gap(8),
       SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
         for(final t in const {'city':'My city','country':'My country',
             'global':'Worldwide'}.entries)
           Padding(padding:const EdgeInsets.only(right:7),
             child:ChoiceChip(label:Text(t.value),selected:area==t.key,
               onSelected:(_){setState(()=>area=t.key);refresh();}))
       ])),
       gap(6),
       DropdownButtonFormField<String>(key:ValueKey('group-topic-$topic'),
         initialValue:topic,isExpanded:true,
         decoration:const InputDecoration(labelText:'Topic',isDense:true),
         items:categories.map((x)=>DropdownMenuItem(value:x,
            child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
         onChanged:(v){setState(()=>topic=v??'All');refresh();}),
       gap(10),
       if(loading)const Padding(padding:EdgeInsets.all(22),
         child:Center(child:CircularProgressIndicator()))
       else if(publicGroups.isEmpty)Card(child:Padding(
           padding:const EdgeInsets.all(18),
           child:const Text('No public groups match yet. Start one from a template '
             'or try another topic or area.')))
       else ...publicGroups.map(publicCard),
       gap(23),

     ])));
}

class ProfilePage extends StatelessWidget {
 const ProfilePage({super.key,required this.profile,required this.onChanged,
   required this.onTheme,required this.themeMode,required this.lookId,
   required this.onLook,required this.onMyReach});
 final Map<String,dynamic> profile;
 final VoidCallback onChanged,onMyReach;
 final ValueChanged<ThemeMode> onTheme;
 final ThemeMode themeMode;
 final String lookId;
 final ValueChanged<String> onLook;

 void openSettings(BuildContext context,{ReachSettingsArea? section}){
   final actions=ReachSettingsActions(
     viewProfile:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>ReachMemberProfilePage(memberId:str(profile['id'])))),
     editProfile:()async{
       await Navigator.push(context,MaterialPageRoute(
         builder:(_)=>EditProfilePage(initial:profile)));
       onChanged();
     },
     manageGroups:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>const CirclesPage())),
     blockedMembers:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>const BlockedPage())),
     business:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>const ReachBusinessStudio())),
     assist:()=>Navigator.push(context,MaterialPageRoute(
       builder:(_)=>const ReachAssistPage())),
     legal:()=>showReachLegalSummary(context),
     support:()=>unawaited(launchUrl(Uri.parse(
       AppConfig.supportEmail.isEmpty
         ?'${AppConfig.legalBase}/contact.html'
         :'mailto:${AppConfig.supportEmail}?subject=Reach%20Support'),
       mode:LaunchMode.externalApplication)),
     signOut:()=>unawaited(busy(context,reach.signOut)),
     deleteAccount:()=>unawaited(deleteAccountFlow(context)),
   );
   Navigator.push(context,MaterialPageRoute(
     builder:(_)=>ReachSettingsHub(
       initialSection:section,profile:profile,
       onProfileChanged:onChanged,actions:actions,
       themeMode:themeMode,onTheme:onTheme,
       lookId:lookId,onLook:onLook,
       callingEnabled:AppConfig.callingEnabled,
       pushEnabled:ReachPush.enabled),
   ));
 }

 @override Widget build(BuildContext context){
   final name=str(profile['display_name']).isEmpty
      ?'Reach member':str(profile['display_name']);
   final username=str(profile['username']);
   return SafeArea(child:ListView(
     padding:const EdgeInsets.fromLTRB(16,14,16,45),children:[
       ReachExperienceHeader(
         title:'Me',subtitle:'Your Reach, your way',
         icon:Icons.account_circle_outlined,
         actions:IconButton(tooltip:'Settings',
           onPressed:()=>openSettings(context),
           icon:const Icon(Icons.settings_outlined))),
       const SizedBox(height:14),
       Card(child:ListTile(
         key:const ValueKey('me-profile'),
         contentPadding:const EdgeInsets.symmetric(horizontal:17,vertical:10),
         leading:ReachAvatar(name:name,
           path:profile['avatar_path'] as String?,
           color:str(profile['avatar_color']),size:60),
         title:Text(name,
           style:Theme.of(context).textTheme.titleMedium?.copyWith(
             fontWeight:FontWeight.w800)),
         subtitle:username.isEmpty
           ?const Text('Profile')
           :Text('@$username',maxLines:1,overflow:TextOverflow.ellipsis),
         trailing:const Icon(Icons.chevron_right_rounded),
         onTap:()=>openSettings(context,section:ReachSettingsArea.profile))),
       const SizedBox(height:11),
       Card(child:Column(children:[
         ListTile(
           key:const ValueKey('me-activity'),
           leading:const Icon(Icons.bolt_outlined),
           title:const Text('My Reach & activity'),
           trailing:const Icon(Icons.chevron_right_rounded),
           onTap:onMyReach),
         const Divider(height:1),
         ListTile(
           key:const ValueKey('me-settings'),
           leading:const Icon(Icons.tune_rounded),
           title:const Text('Settings'),
           trailing:const Icon(Icons.chevron_right_rounded),
           onTap:()=>openSettings(context)),
       ])),
     ]));
 }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key,required this.initial});
  final Map<String,dynamic> initial;
  @override State<EditProfilePage> createState()=>_EditProfilePageState();
}
class _EditProfilePageState extends State<EditProfilePage>{
  late TextEditingController name,username,bio,city,country,skills;
  bool saving=false;
  @override void initState(){
    super.initState();
    final p=widget.initial;
    name=TextEditingController(text:str(p['display_name']));
    username=TextEditingController(text:str(p['username']));
    bio=TextEditingController(text:str(p['bio']));
    city=TextEditingController(text:str(p['city']));
    country=TextEditingController(text:str(p['country']));
    skills=TextEditingController(text:(p['skills'] as List? ?? []).join(', '));
  }
  @override void dispose(){
    for(final c in [name,username,bio,city,country,skills]){c.dispose();}
    super.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Edit profile')),
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
      ReachAvatarEditor(
        name:name.text.isEmpty?'Reach member':name.text,
        initialPath:widget.initial['avatar_path'] as String?,
        initialColor:str(widget.initial['avatar_color']).isEmpty?
          'indigo':str(widget.initial['avatar_color']),
        onSaved:(){}),
      gap(15),
      TextField(controller:name,maxLength:80,textCapitalization:TextCapitalization.words,
        decoration:const InputDecoration(labelText:'Display name')),
      TextField(controller:username,maxLength:24,autocorrect:false,
        textCapitalization:TextCapitalization.none,
        decoration:const InputDecoration(labelText:'Unique login username',
          helperText:'3–24 letters, digits or underscores; start with a letter.')),
      TextField(controller:bio,maxLength:500,maxLines:4,
        decoration:const InputDecoration(labelText:'About me',
          hintText:'A sentence about your interests and experience')),
      TextField(controller:skills,
        decoration:const InputDecoration(labelText:'Skills or credentials (self-declared)',
          hintText:'Excel, plumbing, mathematics, design')),
      gap(10),
      GeoAutocompleteField(controller:country,type:GeoFieldType.country,
        clearCityOnCountryChange:city),
      const SizedBox(height:8),
      GeoAutocompleteField(controller:city,type:GeoFieldType.city,
        countryController:country),
      const SizedBox(height:7),
      gap(18),
      FilledButton(onPressed:saving?null:() async{
        final handle=username.text.trim().toLowerCase();
        if(name.text.trim().length<2 || city.text.trim().isEmpty ||
            country.text.trim().isEmpty ||
            (handle.isNotEmpty&&!RegExp(r'^[a-z][a-z0-9_]{2,23}$').hasMatch(handle))){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Enter your name, city, country and a valid 3–24 character username.')));
          return;
        }
        setState(()=>saving=true);
        final ok=await busy(context,()async{
          await reach.updateProfile({
            'display_name':name.text.trim(),
            'username':handle.isEmpty?null:handle,
            'bio':bio.text.trim(),
            'skills':skills.text.split(',').map((v)=>v.trim()).where((v)=>v.isNotEmpty).take(20).toList(),
            'city':city.text.trim(),
            'country':GeoDirectory.canonicalCountry(country.text)??country.text.trim(),
          });
          return true;
        },success:'Profile updated');
        if(mounted){
          setState(()=>saving=false);
          if(ok==true)Navigator.pop(context);
        }
      },child:const Padding(padding:EdgeInsets.all(14),
        child:Text('Save changes'))),
    ])));
}

class BlockedPage extends StatefulWidget{const BlockedPage({super.key});@override State<BlockedPage> createState()=>_BlockedPageState();}
class _BlockedPageState extends State<BlockedPage>{
 List<Map<String,dynamic>> users=[];bool loading=true;
 @override void initState(){super.initState();refresh();}
 Future<void> refresh()async{final r=await busy(context,reach.blockedUsers);if(mounted)setState((){
  if(r!=null)users=r;loading=false;});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Blocked members')),
  body:loading?const Center(child:CircularProgressIndicator()):users.isEmpty?
   emptyState(context,Icons.shield_outlined,'No blocked members','You control who can contact you.'):
   ListView(children:users.map((u)=>ListTile(title:Text(str(u['display_name'])),
     trailing:TextButton(onPressed:()=>busy(context,()async{await reach.unblockUser(str(u['id']));await refresh();},
       success:'Member unblocked'),child:const Text('Unblock')))).toList()));
}
Future<void> deleteAccountFlow(BuildContext context) async {
 final controller=TextEditingController();
 final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Permanently delete Reach account?'),
   content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('This deletes your profile, offers, requests, messages and circles. It cannot be undone. Enter DELETE to confirm.'),
     gap(12),TextField(controller:controller,decoration:const InputDecoration(hintText:'DELETE'))]),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()=='DELETE'),child:const Text('Delete permanently'))]));
 controller.dispose();
 if(accepted==true && context.mounted)await busy(context,reach.deleteAccount,
   success:'Your account deletion request was completed.');
}


class PasswordRecoveryPage extends StatefulWidget {
 const PasswordRecoveryPage({super.key});
 @override State<PasswordRecoveryPage> createState()=>_PasswordRecoveryPageState();
}
class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
 final password=TextEditingController();bool pending=false;
 @override void dispose(){password.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Reset password')),
  body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
   const ReachMark(),gap(20),Text('Choose a new password',style:Theme.of(context).textTheme.headlineSmall),gap(16),
   TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'New password (8+ characters)')),
   gap(16),FilledButton(onPressed:pending?null:()async{
     if(password.text.length<8)return;
     setState(()=>pending=true);
     await busy(context,()async{
       await Supabase.instance.client.auth.updateUser(UserAttributes(password:password.text));
       await Supabase.instance.client.auth.refreshSession();
     },success:'Password updated.');
     if(mounted)setState(()=>pending=false);
   },child:const Padding(padding:EdgeInsets.all(12),child:Text('Set new password')))
  ])));
}

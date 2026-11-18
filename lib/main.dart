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
import 'reach_themes.dart';
import 'chat_attachment_panel.dart';

late final ReachRepository reach;
const categories = ['All','Technology','Learning','Career','Home & repairs','Sports','Creative','Local knowledge','Other'];
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
  @override Widget build(BuildContext context)=> Container(width:size,height:size,
    decoration:BoxDecoration(gradient:LinearGradient(colors:[Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary],begin:Alignment.topLeft,end:Alignment.bottomRight),
      borderRadius:BorderRadius.circular(size*.3)),
    child:Icon(Icons.waving_hand_rounded,color:Theme.of(context).colorScheme.onPrimary,size:size*.52));
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
  if(e is AuthException) return e.message;
  if(e is PostgrestException) return e.message;
  return e.toString().replaceFirst('Exception: ','').replaceFirst('Bad state: ','');
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
            value:agreed,onChanged:(v)=>setState(()=>agreed=v??false))],
          gap(16),
          FilledButton(onPressed:loading?null:submit,
            child:Padding(padding:const EdgeInsets.all(13),
              child:Text(signup?'Create account':'Sign in'))),
          gap(12),
          if(AppConfig.googleSignInEnabled)
            OutlinedButton.icon(onPressed:loading?null:()=>action(reach.googleSignIn),
            icon:const Icon(Icons.account_circle_outlined),
            label:const Text('Continue with Google')),
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
  int page=0;int revision=0;bool ready=false;Map<String,dynamic> profile={};
  final Set<int> visitedPages={0};
  @override void initState(){super.initState();load();setupPush();}
  Future<void> setupPush() async {
    if(await ReachPush.prepare()) {
      try {await ReachPush.register(Supabase.instance.client);} catch (_) {/* user can deny notifications */}
    }
  }
  Future<void> load() async {
    final p=await busy(context,reach.profile);
    if(mounted&&p!=null) setState((){profile=p;ready=true;});
  }
  void refreshed(){setState(()=>revision++);}
  @override Widget build(BuildContext context){
    if(!ready) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(profile['terms_accepted_at']==null||str(profile['city']).trim().isEmpty||str(profile['country']).trim().isEmpty){
      return ProfileSetup(onComplete:(){load();});
    }
    final pages=<Widget>[
       DiscoverPage(key:ValueKey('discover$revision'),onCreated:refreshed),
       visitedPages.contains(1)?MinePage(key:ValueKey('mine$revision'),onCreated:refreshed):const SizedBox.shrink(),
       visitedPages.contains(2)?const InboxPage():const SizedBox.shrink(),
       visitedPages.contains(3)?const CirclesPage():const SizedBox.shrink(),
       visitedPages.contains(4)?ProfilePage(profile:profile,onChanged:load,onTheme:widget.onTheme,
         themeMode:widget.themeMode,lookId:widget.lookId,onLook:widget.onLook):const SizedBox.shrink()
     ];
     return Scaffold(body:IndexedStack(index:page,children:pages),
       bottomNavigationBar:NavigationBar(selectedIndex:page,onDestinationSelected:(i)=>setState((){
         page=i;visitedPages.add(i);
       }),
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        destinations:const [
          NavigationDestination(icon:Icon(Icons.explore_outlined),selectedIcon:Icon(Icons.explore),label:'Discover'),
          NavigationDestination(icon:Icon(Icons.bolt_outlined),selectedIcon:Icon(Icons.bolt),label:'My Reach'),
          NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Inbox'),
          NavigationDestination(icon:Icon(Icons.groups_outlined),selectedIcon:Icon(Icons.groups),label:'Circles'),
          NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Me'),
        ]));
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
   gap(12),TextField(controller:city,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'City *')),
   gap(12),TextField(controller:country,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Country *')),
   gap(12),CheckboxListTile(value:agree,onChanged:(v)=>setState(()=>agree=v??false),
     title:const Text('I am 18 or older and accept the community rules and privacy policy.'),
     subtitle:const Text('No harassment, fraud, unsafe requests, unwanted contacts, or impersonation.')),
   gap(16),FilledButton(onPressed:()=>busy(context,()async {
     if(city.text.trim().isEmpty||country.text.trim().isEmpty||!agree) throw StateError('Enter your city/country and accept the rules.');
     await reach.updateProfile({'city':city.text.trim(),'country':country.text.trim(),
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
 @override Widget build(BuildContext context)=>SafeArea(child:Column(children:[
  Padding(padding:const EdgeInsets.fromLTRB(18,15,18,0),child:Column(children:[
    Row(children:[const ReachMark(size:42),const SizedBox(width:12),Expanded(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Reach',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
        Text('Good things happen when we connect',style:Theme.of(context).textTheme.bodySmall)])),
      IconButton(tooltip:'Refresh',onPressed:refresh,icon:const Icon(Icons.refresh_rounded))]),gap(20),
    TextField(controller:search,onChanged:(_){debounce?.cancel();debounce=Timer(const Duration(milliseconds:400),refresh);},
      decoration:const InputDecoration(hintText:'Search help, skills or opportunities',prefixIcon:Icon(Icons.search_rounded))),gap(13),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final a in const {'nearby':'Near me','city':'My city','country':'My country','global':'Worldwide'}.entries)
        Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(a.value),selected:area==a.key,
          onSelected:(_){setState(()=>area=a.key);refresh();})),
    ])),gap(6),
    Row(children:[
      Expanded(child:DropdownButtonFormField<String>(initialValue:category,isExpanded:true,
        decoration:const InputDecoration(labelText:'Category',isDense:true),
        items:categories.map((e)=>DropdownMenuItem(value:e,child:Text(e,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v){setState(()=>category=v??'All');refresh();})),
      const SizedBox(width:8),
      Expanded(child:DropdownButtonFormField<String>(initialValue:kind,
        decoration:const InputDecoration(labelText:'Type',isDense:true),
        items:const [DropdownMenuItem(value:'All',child:Text('Everything')),
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
      ListView.builder(padding:const EdgeInsets.fromLTRB(18,0,18,90),itemCount:posts.length,
       itemBuilder:(c,i)=>ReachCard(post:posts[i],onTap:()=>showReachDetail(context,posts[i],onChanged:refresh)) ))),
 ]));
}

class ReachCard extends StatelessWidget {
 const ReachCard({super.key,required this.post,required this.onTap,this.owner=false});
 final ReachPost post;final VoidCallback onTap;final bool owner;
 @override Widget build(BuildContext context){
  final offering=post.kind=='offer';
  final scheme=Theme.of(context).colorScheme;
  final foreground=offering?scheme.onSecondaryContainer:scheme.onTertiaryContainer;
  final stateColor=offering?scheme.secondaryContainer:scheme.tertiaryContainer;
  return Card(margin:const EdgeInsets.only(bottom:12),child:InkWell(
    customBorder:Theme.of(context).cardTheme.shape,onTap:onTap,
   child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
        decoration:BoxDecoration(color:stateColor,borderRadius:BorderRadius.circular(20)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(offering?Icons.volunteer_activism:Icons.pan_tool_alt_outlined,color:foreground,size:15),
         const SizedBox(width:5),Text(offering?'OFFERING HELP':'NEEDS HELP',style:TextStyle(color:foreground,fontWeight:FontWeight.bold,fontSize:11))])),
        const Spacer(),Text(timeago.format(post.createdAt),style:Theme.of(context).textTheme.bodySmall)]),gap(12),
      Text(post.title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
      if(post.detail.isNotEmpty)...[gap(4),Text(post.detail,maxLines:2,overflow:TextOverflow.ellipsis,
        style:Theme.of(context).textTheme.bodyMedium)],gap(12),
      Wrap(spacing:8,runSpacing:8,children:[
        miniTag(Icons.category_outlined,post.category),
        miniTag(Icons.location_city_outlined,'${post.city}, ${post.country}'),
        miniTag(Icons.schedule_rounded,post.expired?'Expired':'Until ${formatTime.format(post.expiresAt)}'),
        if(post.scope=='circle')miniTag(Icons.lock_outline,post.circleName),
      ]),gap(13),const Divider(height:1),gap(10),
      Row(children:[CircleAvatar(radius:14,child:Text(post.ownerName.isEmpty?'?':post.ownerName.characters.first.toUpperCase(),style:const TextStyle(fontSize:12))),
        const SizedBox(width:9),Expanded(child:Text(owner?'Your reach':post.ownerName,
          overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600))),
        Text(owner?'Manage':'View & connect',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold,fontSize:12)),
        Icon(Icons.chevron_right,color:Theme.of(context).colorScheme.primary),
      ])
    ]))));
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
        DropdownMenuItem(value:'fraud',child:Text('Fraud / impersonation')),
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
 const ComposePage({super.key,this.initialType='offer'});final String initialType;
 @override State<ComposePage> createState()=>_ComposePageState();
}
class _ComposePageState extends State<ComposePage>{
 final title=TextEditingController(),detail=TextEditingController();
 String type='offer',category='Technology',duration='1 hour',circleId='public';
 List<Map<String,dynamic>> circles=[];bool saving=false;
 final durations={'30 minutes':const Duration(minutes:30),'1 hour':const Duration(hours:1),
   '3 hours':const Duration(hours:3),'Today':const Duration(hours:24),'7 days':const Duration(days:7)};
 @override void initState(){super.initState();type=widget.initialType;load();}
 Future<void> load()async{final c=await busy(context,reach.circles);if(mounted&&c!=null)setState(()=>circles=c);}
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
   DropdownButtonFormField<String>(initialValue:circleId,decoration:const InputDecoration(labelText:'Visible to'),
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
 int tab=0;bool loading=true;
 List<ReachRequest> incoming=[],outgoing=[];
 List<Map<String,dynamic>> conversations=[],alerts=[];
 @override void initState(){super.initState();refresh();}
 Future<void> refresh()async{
  final values=await Future.wait<Object?>([
    busy(context,()=>reach.requests()),
    busy(context,()=>reach.requests(incoming:false)),
    busy(context,reach.conversations),
    busy(context,reach.alerts)
  ]);
  if(mounted)setState((){
    final a=values[0] as List<ReachRequest>?;
    final b=values[1] as List<ReachRequest>?;
    final c=values[2] as List<Map<String,dynamic>>?;
    final d=values[3] as List<Map<String,dynamic>>?;
    if(a!=null)incoming=a;if(b!=null)outgoing=b;
    if(c!=null)conversations=c;if(d!=null)alerts=d;loading=false;
  });
 }
 @override Widget build(BuildContext context)=>SafeArea(child:Column(children:[
  Padding(padding:const EdgeInsets.fromLTRB(18,17,18,8),child:sectionHeader(context,'Inbox',
    subtitle:'Messages open only after you agree',trailing:IconButton(onPressed:refresh,icon:const Icon(Icons.refresh)))),
  Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:SegmentedButton<int>(
    segments:const [ButtonSegment(value:0,label:Text('Chats')),ButtonSegment(value:1,label:Text('Requests')),
      ButtonSegment(value:2,label:Text('Alerts'))],selected:{tab},
    onSelectionChanged:(v){setState(()=>tab=v.first);if(tab==2)busy(context,reach.readAlerts);})),gap(10),
  Expanded(child:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,
    child:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,40),children:tab==0?_chatRows():tab==1?_requestRows():_alertRows()))),
 ]));
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
   if(incoming.isEmpty&&outgoing.isEmpty)return [gap(80),emptyState(context,Icons.handshake_outlined,
     'No requests','Tap “View & connect” on an offer or request to introduce yourself.')];
   return [if(incoming.isNotEmpty)...[Text('Received',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),gap(8)],
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
 @override void dispose(){text.dispose();super.dispose();}
 Future<void> send()async{
  final message=text.text.trim();if(message.isEmpty||message.length>2000||sending)return;
  setState(()=>sending=true);
  final sent=await busy(context,()async{await reach.sendMessage(widget.conversationId,message);return true;});
  if(mounted){if(sent==true)text.clear();setState(()=>sending=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(
   title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.peerName),
     Text(widget.topic,style:Theme.of(context).textTheme.bodySmall,maxLines:1,overflow:TextOverflow.ellipsis)]),
   actions:[PopupMenuButton<String>(onSelected:(v)async{
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
          decoration:BoxDecoration(color:mine?Theme.of(c).colorScheme.primaryContainer:
            Theme.of(c).colorScheme.surfaceContainerHigh,borderRadius:BorderRadius.circular(17)),
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
    ChatAttachmentsPanel(conversationId:widget.conversationId),
    Container(padding:const EdgeInsets.fromLTRB(12,8,8,9),decoration:BoxDecoration(
      color:Theme.of(context).colorScheme.surface),
     child:Row(children:[Expanded(child:TextField(controller:text,maxLength:2000,minLines:1,maxLines:4,
       textCapitalization:TextCapitalization.sentences,
       decoration:const InputDecoration(hintText:'Write a message',counterText:'',border:InputBorder.none))),
       IconButton(onPressed:sending?null:send,icon:const Icon(Icons.send_rounded),tooltip:'Send')]))
   ])));
}

class CirclesPage extends StatefulWidget{const CirclesPage({super.key});@override State<CirclesPage> createState()=>_CirclesPageState();}
class _CirclesPageState extends State<CirclesPage>{
 bool loading=true;List<Map<String,dynamic>> circles=[];
 @override void initState(){super.initState();refresh();}
 Future<void> refresh()async{final c=await busy(context,reach.circles);if(mounted)setState((){
   if(c!=null)circles=c;loading=false;});}
 Future<void> newCircle()async{
   final name=await askText(context,title:'Create private circle',hint:'e.g. Neighborhood volunteers');
   if(name!=null&&name.length>=3&&mounted)await busy(context,()async{await reach.createCircle(name);await refresh();},success:'Private circle created');
 }
 Future<void> join()async{
   final code=await askText(context,title:'Join a circle',hint:'Enter invitation code');
   if(code!=null&&code.isNotEmpty&&mounted)await busy(context,()async{await reach.joinCircle(code);await refresh();},success:'Circle joined');
 }
 @override Widget build(BuildContext context)=>SafeArea(child:RefreshIndicator(onRefresh:refresh,child:
  ListView(padding:const EdgeInsets.fromLTRB(18,17,18,40),children:[
   sectionHeader(context,'My circles',subtitle:'Your private, trusted communities'),
   Row(children:[Expanded(child:FilledButton.icon(onPressed:newCircle,icon:const Icon(Icons.add),label:const Text('Create circle'))),
     const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:join,
       icon:const Icon(Icons.group_add_outlined),label:const Text('Join circle')))]),gap(14),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
     const Icon(Icons.lock_outline),const SizedBox(width:10),
     Expanded(child:Text('Circle-only posts are visible to members. Invitation codes should be shared only with people you trust.',
       style:Theme.of(context).textTheme.bodySmall))]))),gap(14),
   if(loading)const Center(child:CircularProgressIndicator())
   else if(circles.isEmpty)emptyState(context,Icons.groups_outlined,'No circles yet',
     'Start with your classmates, coworkers, or local community.')
   else ...circles.map((c)=>Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
     ListTile(leading:CircleAvatar(child:Text(str(c['name']).characters.first.toUpperCase())),
       title:Text(str(c['name']),style:const TextStyle(fontWeight:FontWeight.bold)),
       subtitle:Text('${c['member_count']} members · ${c['owner_id']==reach.uid?'Owner':'Member'}')),
     Row(children:[Expanded(child:Text('Invite: ${c['invite_code']}',
        textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)),
       TextButton.icon(onPressed:()=>SharePlus.instance.share(ShareParams(
         text:'Join my private Reach circle “${c['name']}”. Install Reach and enter code: ${c['invite_code']}')),
         icon:const Icon(Icons.share_outlined,size:17),label:const Text('Invite')),
       if(c['owner_id']==reach.uid)IconButton(tooltip:'Delete circle',onPressed:()async{
         final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
            title:const Text('Delete this circle?'),content:const Text('Members, circle posts and related chats will be removed. This cannot be undone.'),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
              FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
         if(confirmed==true && mounted)await busy(context,()async{await reach.deleteCircle(str(c['id']));await refresh();},
             success:'Circle deleted');
       },icon:const Icon(Icons.delete_outline,size:18)),
       if(c['owner_id']!=reach.uid)IconButton(tooltip:'Leave circle',onPressed:()async{
         await busy(context,()async {await reach.leaveCircle(str(c['id']));await refresh();});
       },icon:const Icon(Icons.logout,size:18)),
     ])])))),
  ])));
}

class ProfilePage extends StatelessWidget {
 const ProfilePage({super.key,required this.profile,required this.onChanged,
   required this.onTheme,required this.themeMode,required this.lookId,required this.onLook});
 final Map<String,dynamic> profile;final VoidCallback onChanged;
 final ValueChanged<ThemeMode> onTheme;final ThemeMode themeMode;
 final String lookId;final ValueChanged<String> onLook;
 @override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,45),children:[
   sectionHeader(context,'My profile',subtitle:'Your identity and privacy controls'),gap(12),
   Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[
     const ReachMark(size:58),const SizedBox(width:14),Expanded(child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text(str(profile['display_name']).isEmpty?'Reach member':str(profile['display_name']),
           style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
         if(str(profile['username']).isNotEmpty) Text('@${profile['username']}'),
         Text('${profile['city']}, ${profile['country']}'),
         Text('Self-declared skills · no identity verification',
           style:Theme.of(context).textTheme.bodySmall)
       ]))]))),gap(14),
   Card(child:Column(children:[
     ListTile(leading:const Icon(Icons.edit_outlined),title:const Text('Edit profile and skills'),
       subtitle:const Text('Username, name, biography, specialties and city'),trailing:const Icon(Icons.chevron_right),
       onTap:()async {await Navigator.push(context,MaterialPageRoute(
         builder:(_)=>EditProfilePage(initial:profile)));onChanged();}),
     const Divider(height:1),
     SwitchListTile(secondary:const Icon(Icons.location_on_outlined),
       title:const Text('Nearby discovery'),subtitle:const Text('Opt-in: only a rounded location grid is stored.'),
       value:profile['location_opt_in']==true,onChanged:(v)async{
         if(v){await busy(context,()async{
           await reach.setApproxLocation();await reach.updateProfile({'location_opt_in':true});
         },success:'Nearby discovery enabled');}
         else {await busy(context,()async{
           await reach.forgetLocation();await reach.updateProfile({'location_opt_in':false});
         },success:'Location removed');}
         onChanged();
       }),
     const Divider(height:1),
     SwitchListTile(secondary:const Icon(Icons.notifications_none),
       title:const Text('In-app activity alerts'),
       subtitle:Text(ReachPush.enabled?'Receive alerts (if permission is granted)':'Background notifications require Firebase configuration.'),
       value:profile['notify_on']==true,onChanged:(v)async{
          await busy(context,()=>reach.updateProfile({'notify_on':v}));onChanged();
       }),
   ])),gap(14),
   Card(child:Column(children:[
     ListTile(leading:const Icon(Icons.palette_outlined),title:const Text('Appearance'),
       subtitle:Text('Current: ${themeMode.name}'),trailing:DropdownButton<ThemeMode>(
         underline:const SizedBox.shrink(),value:themeMode,
         items:ThemeMode.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.name))).toList(),
         onChanged:(v){if(v!=null)onTheme(v);}),),
     ListTile(leading:const Icon(Icons.auto_awesome_outlined),
       title:const Text('Design studio · 10 full-app themes'),
       subtitle:Text('Current: ${reachLookById(lookId).name} · colors, cards, buttons and navigation'),
       trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,
         MaterialPageRoute(builder:(_)=>ReachThemeGallery(selected:lookId,onSelected:onLook)))),
     const Divider(height:1),
     ListTile(leading:const Icon(Icons.block_outlined),title:const Text('Blocked members'),
       trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,
         MaterialPageRoute(builder:(_)=>const BlockedPage()))),
     const Divider(height:1),
     ListTile(leading:const Icon(Icons.policy_outlined),title:const Text('Privacy and community rules'),
       trailing:const Icon(Icons.chevron_right),onTap:()=>showModalBottomSheet<void>(context:context,
         isScrollControlled:true,showDragHandle:true,builder:(c)=>Padding(
           padding:const EdgeInsets.all(22),child:SingleChildScrollView(child:Column(
             mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
               Text('Community commitments',style:Theme.of(c).textTheme.titleLarge),gap(12),
               const Text('Reach is intended for adults 18+. Be respectful. Do not post scams, impersonations, hate, sexual exploitation, illegal requests, dangerous instructions, spam, phone numbers, exact home addresses, or sensitive personal information. Report unsafe content and block unwanted contact. Self-described credentials are not verified.'),
               gap(12),const Text('Privacy: We store profile data, posts, requests, chat messages, reports, circles, and optionally approximate location in your Supabase instance. Discovery never exposes the stored coordinate grid. Review and replace legal/PRIVACY.md with the real operator’s policy before release.'),
               gap(12),if(AppConfig.legalBase.isNotEmpty)TextButton(
                 onPressed:()=>launchUrl(Uri.parse('${AppConfig.legalBase}/privacy.html')),
                 child:const Text('Read full privacy policy')),
               gap(8),FilledButton(onPressed:()=>popSafe(c),child:const Text('Close'))]))))),
     const Divider(height:1),
     ListTile(leading:const Icon(Icons.mail_outline),title:const Text('Support'),
       subtitle:Text(AppConfig.supportEmail.isEmpty?'Configure support email before launch':AppConfig.supportEmail),
       onTap:AppConfig.supportEmail.isEmpty?null:()=>launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=Reach%20Support'))),
   ])),gap(14),
   Card(child:Column(children:[
     ListTile(leading:const Icon(Icons.logout),title:const Text('Sign out'),
       onTap:()=>busy(context,reach.signOut)),
     const Divider(height:1),
     ListTile(leading:const Icon(Icons.delete_forever_outlined,color:Colors.red),
       title:const Text('Delete my account',style:TextStyle(color:Colors.red)),
       subtitle:const Text('Permanently erase your account, posts and chats'),
       onTap:()=>deleteAccountFlow(context)),
   ])),gap(18),Center(child:Text('Reach 1.0.0 · Built for trust and usefulness',
      style:Theme.of(context).textTheme.labelSmall)),
 ]));
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
      const Text('Only add credentials you genuinely hold. Reach does not independently verify skills.'),
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
      TextField(controller:city,maxLength:100,textCapitalization:TextCapitalization.words,
        decoration:const InputDecoration(labelText:'City')),
      TextField(controller:country,maxLength:100,textCapitalization:TextCapitalization.words,
        decoration:const InputDecoration(labelText:'Country')),
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
            'city':city.text.trim(),'country':country.text.trim(),
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

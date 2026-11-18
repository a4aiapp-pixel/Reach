import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Business onboarding is a review-only pilot until verified Play/external
/// payments and real sponsorship approvals are configured by the operator.
/// No payment, priority placement or verification is implied here.
class ReachBusinessStudio extends StatefulWidget {
  const ReachBusinessStudio({super.key});
  @override State<ReachBusinessStudio> createState()=>_ReachBusinessStudioState();
}

class _ReachBusinessStudioState extends State<ReachBusinessStudio> {
  final name=TextEditingController(),description=TextEditingController(),
      city=TextEditingController(),country=TextEditingController(),
      website=TextEditingController();
  bool loading=true,saving=false;
  String status='draft';
  bool exists=false;

  @override void initState(){super.initState();load();}
  @override void dispose(){
    for(final c in [name,description,city,country,website]){c.dispose();}
    super.dispose();
  }
  void notice(Object e){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(e.toString().replaceFirst('Bad state: ',''))));
  }
  Future<void> load()async{
    try{
      final user=Supabase.instance.client.auth.currentUser;
      if(user==null)throw StateError('Sign in first.');
      final row=await Supabase.instance.client.from('reach_business_profiles')
        .select().eq('owner_id',user.id).maybeSingle();
      if(row!=null){
        name.text=row['business_name'] as String? ?? '';
        description.text=row['description'] as String? ?? '';
        city.text=row['city'] as String? ?? '';
        country.text=row['country'] as String? ?? '';
        website.text=row['website'] as String? ?? '';
        status=row['review_status'] as String? ?? 'draft';
        exists=true;
      }
    }catch(e){notice(e);}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> save()async{
    final title=name.text.trim();
    final url=website.text.trim();
    if(title.length<3||description.text.length>650||
       (url.isNotEmpty&&!url.startsWith('https://'))){
      notice('Provide a business name (3+ characters) and an HTTPS website if supplied.');
      return;
    }
    if(status=='published'||status=='suspended'){
      notice('Published or suspended profiles must be edited through Reach support.');
      return;
    }
    setState(()=>saving=true);
    try{
      final client=Supabase.instance.client;
      final user=client.auth.currentUser;
      if(user==null)throw StateError('Sign in first.');
      final data=<String,dynamic>{
        'business_name':title,'description':description.text.trim(),
        'city':city.text.trim(),'country':country.text.trim(),
        'website':url.isEmpty?null:url,'review_status':'submitted',
        'updated_at':DateTime.now().toUtc().toIso8601String(),
      };
      if(exists){
        await client.from('reach_business_profiles').update(data)
          .eq('owner_id',user.id);
      }else{
        await client.from('reach_business_profiles')
          .insert({...data,'owner_id':user.id});
      }
      setState((){exists=true;status='submitted';});
      notice('Business profile submitted for manual review. No fee was charged.');
    }catch(e){notice(e);}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Reach for Business')),
    body:SafeArea(child:loading?
      const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.all(20),children:[
        const Icon(Icons.business_center_outlined,size:46),
        const SizedBox(height:10),
        Text('Professional presence, built on trust',
          style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:8),
        const Text('Business profiles and sponsored opportunities are currently in preparation. '
          'Submitting details expresses interest; it does not activate a subscription, '
          'verification badge, or paid placement. Everyday Reach remains free.'),
        const SizedBox(height:16),
        Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(
          children:[
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width:12),
            Expanded(child:Text('Review status: ${status.toUpperCase()}',
              style:Theme.of(context).textTheme.titleMedium)),
          ]))),
        const SizedBox(height:16),
        TextField(controller:name,maxLength:100,
          decoration:const InputDecoration(labelText:'Registered business or professional name')),
        TextField(controller:description,maxLength:650,maxLines:3,
          decoration:const InputDecoration(labelText:'What services do you provide?')),
        TextField(controller:city,maxLength:100,
          decoration:const InputDecoration(labelText:'City')),
        const SizedBox(height:10),
        TextField(controller:country,maxLength:100,
          decoration:const InputDecoration(labelText:'Country')),
        const SizedBox(height:10),
        TextField(controller:website,maxLength:250,
          keyboardType:TextInputType.url,
          decoration:const InputDecoration(labelText:'Website (optional, HTTPS only)')),
        const SizedBox(height:16),
        FilledButton(onPressed:saving?null:save,
          child:Padding(padding:const EdgeInsets.all(13),
            child:Text(saving?'Submitting…':'Submit for review'))),
        const SizedBox(height:12),
        Text('Payments and sponsorships are disabled until identity, '
          'billing and moderation requirements are satisfied.',
          style:Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repository.dart';

/// Adult-only access. DOB is sent only to the age-check RPC and is not
/// persisted in the database or app preferences. This is self-declaration,
/// not documentary, biometric or third-party age verification.
class ReachAdultGate extends StatefulWidget {
  const ReachAdultGate({super.key,required this.onComplete});
  final VoidCallback onComplete;
  @override State<ReachAdultGate> createState()=>_ReachAdultGateState();
}
class _ReachAdultGateState extends State<ReachAdultGate> {
  DateTime? birthday;
  bool confirmed=false,busy=false;
  Future<void> chooseDate() async {
    final now=DateTime.now();
    final date=await showDatePicker(context:context,
      initialDate:DateTime(now.year-20,now.month,now.day),
      firstDate:DateTime(now.year-115,1,1),
      lastDate:now,
      helpText:'Confirm your age for adult community access');
    if(date!=null&&mounted)setState(()=>birthday=date);
  }
  Future<void> submit() async {
    final date=birthday;
    if(date==null||!confirmed||busy)return;
    setState(()=>busy=true);
    try {
      await ReachRepository(Supabase.instance.client).confirmAdult(date);
      if(mounted)widget.onComplete();
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.toString().replaceFirst('Bad state: ',''))));
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Age & community safety')),
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:460),
      child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),
        children:[
          const Icon(Icons.verified_user_outlined,size:64),
          const SizedBox(height:17),
          Text('Reach is for adults 18+',
            textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:12),
          const Text('To protect the community, confirm your age before '
            'searching for people, publishing, messaging or using calls. '
            'Your birth date is checked and is not saved. '
            'This check is self-attested and does not verify government ID.',
            textAlign:TextAlign.center),
          const SizedBox(height:22),
          OutlinedButton.icon(onPressed:chooseDate,
            icon:const Icon(Icons.calendar_month_outlined),
            label:Text(birthday==null?'Choose date of birth':
              '${birthday!.day}/${birthday!.month}/${birthday!.year}')),
          const SizedBox(height:11),
          CheckboxListTile(value:confirmed,controlAffinity:ListTileControlAffinity.leading,
            contentPadding:EdgeInsets.zero,
            onChanged:(value)=>setState(()=>confirmed=value??false),
            title:const Text('I confirm that the information is accurate '
              'and that I am at least 18 years old.')),
          const SizedBox(height:14),
          FilledButton(onPressed:busy||birthday==null||!confirmed?null:submit,
            child:Padding(padding:const EdgeInsets.all(14),
              child:Text(busy?'Checking age…':'Confirm and continue'))),
          const SizedBox(height:14),
          Text('Reports, blocks, rate limits and content safety controls '
            'remain active. Do not share passwords or payment codes.',
            style:Theme.of(context).textTheme.bodySmall,
            textAlign:TextAlign.center),
        ]),
    ))));
}

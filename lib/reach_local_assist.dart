/// Zero-cost, offline Reach writing and safety helper.
///
/// This is a deterministic utility, not a generative model: it makes no
/// network requests, needs no account/payment/API key, and stores no history.
/// Always label it "local smart tools" rather than implying cloud AI.
class ReachLocalAssist {
  const ReachLocalAssist._();

  static const modes = <String,String>{
    'chat':'Reach guidance',
    'draft':'Draft a post',
    'polish':'Polish writing',
    'translate':'Common phrases',
    'safety':'Safety check',
    'ideas':'Community ideas',
  };

  static String respond(String mode,String input) {
    final text=input.trim();
    if(text.isEmpty)return 'Write a message or choose a suggestion.';
    if(text.length>1800)return 'Please shorten the message to 1,800 characters.';
    return switch(mode){
      'draft'=>draft(text),
      'polish'=>polish(text),
      'translate'=>phrases(text),
      'safety'=>safety(text),
      'ideas'=>ideas(text),
      _=>guidance(text),
    };
  }

  static bool _any(String s,Iterable<String> words)=>
    words.any((term)=>s.contains(term));

  static String _normal(String text)=>text.toLowerCase().trim();

  /// Basic non-generative correction; preserve original facts and don't
  /// invent a place, a price, identity or credentials.
  static String cleanText(String value){
    var s=value.trim().replaceAll(RegExp(r'\s+'),' ');
    const simple=<String,String>{
      'pls':'please','plz':'please','thx':'thanks','u':'you',
      'ur':'your','im':"I'm",'dont':"don't",'cant':"can't",
      'wont':"won't",'i':'I',
    };
    s=s.replaceAllMapped(RegExp(r"\b(pls|plz|thx|u|ur|im|dont|cant|wont|i)\b",caseSensitive:false),
      (m)=>simple[m.group(0)!.toLowerCase()]??m.group(0)!);
    s=s.replaceAllMapped(RegExp(r'\s+([,.!?;:])'),(m)=>m.group(1)!)
      .replaceAllMapped(RegExp(r'([,.!?;:])(?=[A-Za-z])'),
        (m)=>m.group(1)!+' ');
    if(s.isNotEmpty)s=s[0].toUpperCase()+s.substring(1);
    if(s.isNotEmpty&&!RegExp(r'[.!?]$').hasMatch(s))s='$s.';
    return s;
  }

  static String polish(String value){
    final output=cleanText(value);
    return 'Suggested wording (review before sharing):\n\n$output\n\n'
      'Local editing corrects common abbreviations, punctuation and spacing only. '
      'It is not an advanced grammar model; check names, addresses and meaning.';
  }

  static String _topic(String s){
    if(_any(s,['excel','computer','software','code','phone','internet','laptop'])){
      return 'Technology';
    }
    if(_any(s,['math','english','school','study','tutor','teach','lesson'])){
      return 'Learning';
    }
    if(_any(s,['job','resume','career','interview','cv ','employment'])){
      return 'Career';
    }
    if(_any(s,['repair','plumb','electric','paint','house','water','wiring'])){
      return 'Home & repairs';
    }
    if(_any(s,['art','design','music','draw','photo','video'])){
      return 'Creative';
    }
    if(_any(s,['sport','fitness','run','football','cricket'])){
      return 'Sports';
    }
    return 'Local knowledge';
  }

  static String draft(String message){
    final lower=_normal(message);
    final offering=_any(lower,['i can','i offer','offering','i teach',
      'available to help','volunteer','i will help','i could help']);
    final topic=_topic(lower);
    final body=cleanText(message);
    if(_any(lower,['password','bank account','otp code','cvv'])){
      return 'Remove passwords, bank details, verification codes and other secrets '
        'before posting. Reach posts may be seen by other members.';
    }
    final label=offering?'Offer to help':'Request for help';
    final target=offering?'People who could benefit':'What help I need';
    return '$label · $topic\n\n$body\n\n'
      '$target: [brief details]\n'
      'Preferred city or area: [choose approximate area]\n'
      'Availability: [day or time window]\n'
      'How to connect: Reply through Reach.\n\n'
      'Replace bracketed placeholders yourself, then review the post. '
      'Do not publish exact home addresses, passwords, or unnecessary personal data. '
      'Nothing has been posted automatically.';
  }

  static String safety(String message){
    final s=_normal(message);
    final warnings=<String>[];
    if(_any(s,['otp','verification code','password','pin code','2fa',
      'two factor','cvv','security code'])){
      warnings.add('Never share passwords, verification codes, PINs or CVVs.');
    }
    if(_any(s,['deposit','advance payment','upfront','gift card',
      'transfer money','crypto','wallet'])){
      warnings.add('Be cautious of advance payments, irreversible transfers and gift-card requests.');
    }
    if(_any(s,['cnic','passport','id card','bank details','bank account',
      'credit card','debit card'])){
      warnings.add('Keep identity documents and financial information private.');
    }
    if(_any(s,['secret','keep quiet','urgent','immediately','limited time',
      'act now','guaranteed'])){
      warnings.add('Pressure, secrecy and guaranteed outcomes can be manipulation signals.');
    }
    if(_any(s,['private home','come alone','meet alone','unknown person',
      'stranger','late night'])){
      warnings.add('Choose a public meeting place and tell a trusted person your plan.');
    }
    if(_any(s,['http://','bit.ly','tinyurl','short link'])){
      warnings.add('Inspect links carefully; do not sign into accounts from unsolicited links.');
    }
    if(_any(s,['remote access','screen share','install apk','download apk'])){
      warnings.add('Do not install unknown apps or grant remote control of your device.');
    }
    final prefix=warnings.isEmpty
      ? 'No matching warning pattern found. This is NOT proof the message or person is safe.'
      : 'Potential risk signals found (not a verified fraud finding):';
    final lines=warnings.isEmpty?'':warnings.map((w)=>'• $w').join('\n');
    return '$prefix\n\n$lines\n\n'
      'Verify identities independently, keep initial contact in Reach, '
      'never send one-time codes or money under pressure, and use Report/Block '
      'if uncomfortable. Automated rules cannot verify a real account or guarantee safety.';
  }

  static String phrases(String input){
    final s=_normal(input);
    // Do not pretend arbitrary free-form translation is possible without a model.
    if(_any(s,['translate this','convert this','translate my',
      'translate the following','in urdu:','into urdu:','to english:'])){
      return 'Free offline mode offers a small verified phrasebook, '
        'not arbitrary machine translation. For a custom translation, '
        'use a trusted on-device translator or the optional cloud feature '
        'only when explicitly enabled.\n\n'
        '${_phrasebook()}';
    }
    return _phrasebook();
  }

  static String _phrasebook()=>'''
Common Reach phrases · English / اردو

Hello — السلام علیکم
Thank you — شکریہ
I need help — مجھے مدد چاہیے
Can you help me? — کیا آپ میری مدد کر سکتے ہیں؟
I can help — میں مدد کر سکتا/سکتی ہوں
Please reply here — براہ کرم یہیں جواب دیں
When are you available? — آپ کب دستیاب ہیں؟
Let's meet in a public place — آئیے کسی عوامی جگہ پر ملتے ہیں

These are fixed everyday phrases, not translation of your message. Check wording for context.
''';

  static String ideas(String message){
    final cat=_topic(_normal(message));
    final options=switch(cat){
      'Technology'=>[
        'Offer a short device-setup or spreadsheet help session.',
        'Help people learn online safety and account recovery basics.',
        'Organize a small digital-skills exchange.',
      ],
      'Learning'=>[
        'Set up a peer-to-peer homework hour.',
        'Offer an introductory skills exchange.',
        'Share a beginner-friendly learning checklist.',
      ],
      'Home & repairs'=>[
        'Run a safe neighborhood maintenance Q&A.',
        'Exchange household repair guidance without risky electrical work.',
        'Organize a tool-sharing directory with clear consent and return rules.',
      ],
      'Career'=>[
        'Host a CV review circle.',
        'Pair volunteers for interview practice.',
        'Share a local job-search skills workshop.',
      ],
      _=>[
        'Create a neighborhood skills exchange.',
        'Organize a voluntary community learning circle.',
        'Start a small mutual-help group around a shared interest.',
      ],
    };
    return 'Community ideas · $cat\n\n'
      '${options.map((x)=>'• $x').join('\n')}\n\n'
      'Start with a clear voluntary invitation, an approximate area, '
      'a time window and safe messaging inside Reach. These are suggestions, '
      'not live verified events or local member matches.';
  }

  static String guidance(String text){
    final s=_normal(text);
    if(_any(s,['hi','hello','hey','assalam','salam'])&&s.length<20){
      return 'Welcome to Reach. I can help you draft a request or offer, '
        'polish your message, explore community ideas, or check common '
        'scam patterns. All these local tools work without a network or AI bill.';
    }
    if(_any(s,['translate','urdu','english'])){
      return phrases(text);
    }
    if(_any(s,['scam','spam','fake','fraud','safe','danger','otp','trust'])){
      return safety(text);
    }
    if(_any(s,['write','draft','request','post','offer help','need help'])){
      return draft(text);
    }
    if(_any(s,['idea','suggest','community','volunteer','neighbor'])){
      return ideas(text);
    }
    if(_any(s,['grammar','polish','correct','rewrite','improve'])){
      return polish(text);
    }
    return 'I can assist without an online AI model using these free tools:\n\n'
      '• Draft a community help request or offer\n'
      '• Polish spacing, punctuation and common abbreviations\n'
      '• Check common scam and privacy warning patterns\n'
      '• Show everyday English–Urdu phrases\n'
      '• Suggest community projects\n\n'
      'Choose a task above and enter your details. I cannot answer '
      'arbitrary factual questions offline or access live Reach listings; '
      'no network AI is running in this mode.';
  }
}

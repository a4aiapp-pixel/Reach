import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models.dart';

class ReachRepository {
  ReachRepository(this.client);
  final SupabaseClient client;
  String get uid => client.auth.currentUser?.id ?? '';

  Future<void> signUp(String email, String password, String name, String username) async {
    await client.auth.signUp(email: email, password: password,
      data: {'display_name': name.trim(), 'username': username.trim().toLowerCase()},
      emailRedirectTo: AppConfig.callback);
  }
  Future<void> signIn(String identifier, String password) async {
    final login = identifier.trim();
    if (login.contains('@')) {
      await client.auth.signInWithPassword(email: login, password: password);
      return;
    }
    // A public client cannot obtain a user's email from their username.
    // Resolve the username and verify the password only inside our
    // rate-limited Edge Function, then establish the returned Gotrue session.
    dynamic data;
    try {
      final response = await client.functions.invoke('username-login',
        body: {'username': login.toLowerCase(), 'password': password});
      data = response.data;
    } catch (_) {
      throw StateError('Username login failed. Check your credentials or try again later.');
    }
    if (data is! Map ||
        data['refresh_token'] is! String || data['access_token'] is! String) {
      throw StateError('Username login failed. Please try again.');
    }
    await client.auth.setSession(data['refresh_token'] as String,
      accessToken: data['access_token'] as String);
  }
  Future<void> verifySignupCode(String email, String code) async {
    await client.auth.verifyOTP(type: OtpType.signup,
      token: code.trim(), email: email.trim());
  }
  Future<void> resendSignup(String email) async {
    await client.auth.resend(type: OtpType.signup,
      email: email.trim(), emailRedirectTo: AppConfig.callback);
  }
  Future<void> magicLink(String email) async =>
      client.auth.signInWithOtp(email: email, emailRedirectTo: AppConfig.callback,
        shouldCreateUser: false);
  Future<void> resetPassword(String email) async =>
      client.auth.resetPasswordForEmail(email, redirectTo: AppConfig.callback);
  Future<void> googleSignIn() async {
    await client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: AppConfig.callback);
  }
  Future<void> signOut() async {
    await client.from('device_tokens').delete().eq('user_id', uid);
    await client.auth.signOut();
  }

  Future<Map<String, dynamic>> profile() async =>
      Map<String, dynamic>.from(await client.from('profiles').select().eq('id', uid).single());
  /// A successful HTTP response alone is not proof a preference changed: an
  /// RLS-filtered UPDATE may affect zero rows. Require the returned own profile,
  /// then verify privacy/calling switches against the database response.
  Future<void> updateProfile(Map<String, dynamic> values) async {
    final me=uid;
    if(me.isEmpty)throw StateError('Sign in before updating your profile.');
    if(values.isEmpty)return;
    final row=Map<String,dynamic>.from(
      await client.from('profiles').update(values).eq('id',me)
        .select().single());
    if(row['id']!=me)throw StateError('Profile update was not confirmed.');
    for(final entry in values.entries){
      if((entry.value is bool || entry.key=='profile_visibility') &&
          row[entry.key]!=entry.value){
        throw StateError('Profile preference could not be confirmed as saved.');
      }
    }
  }

  Future<void> confirmAdult(DateTime birthday) async {
    final date='${birthday.year.toString().padLeft(4,'0')}-'
      '${birthday.month.toString().padLeft(2,'0')}-'
      '${birthday.day.toString().padLeft(2,'0')}';
    await client.rpc('reach_confirm_adult',params:{'p_birth_date':date});
  }

  Future<List<Map<String,dynamic>>> discoverPeople({
      String area='city',String query=''}) async {
    final result=await client.rpc('reach_discover_people',
      params:{'p_area':area,'p_query':query.trim()});
    return (result as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<void> requestMember(String recipient,String message) async {
    await client.rpc('reach_request_member',params:{
      'p_recipient':recipient,'p_message':message.trim(),
    });
  }

  Future<void> answerMember(String requestId,bool accept) async {
    await client.rpc('reach_answer_member',params:{
      'p_request':requestId,'p_accept':accept,
    });
  }

  Future<List<Map<String,dynamic>>> memberRequests() async {
    final result=await client.rpc('reach_member_requests');
    return (result as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<bool> canCall(String peerId) async {
    final value=await client.rpc('reach_can_call',params:{'p_peer':peerId});
    return value==true;
  }

  Future<void> setApproxLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Device location is turned off. Enable it in Settings.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission was not granted.');
    }
    final p = await Geolocator.getCurrentPosition(locationSettings:
      const LocationSettings(accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15)));
    // Approximate location: lat/lon rounded to about 11 km grid. Never send exact GPS.
    final lat = (p.latitude * 10).round() / 10.0;
    final lon = (p.longitude * 10).round() / 10.0;
    await client.from('approx_locations').upsert({
      'user_id': uid, 'lat': lat, 'lon': lon,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
  Future<void> forgetLocation() async =>
      client.from('approx_locations').delete().eq('user_id', uid).then((_) {});

  Future<List<ReachPost>> discover({String area = 'city', String keyword = '',
      String category = 'All', String kind = 'All', int radiusKm = 25}) async {
    final result = await client.rpc('discover_reaches', params: {
      'p_area': area,
      'p_keyword': keyword,
      'p_category': category,
      'p_kind': kind,
      'p_radius_km': radiusKm,
    });
    return (result as List).map((e) => ReachPost.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  Future<List<ReachPost>> myPosts() async {
    final result = await client.rpc('my_reaches');
    return (result as List).map((e) => ReachPost.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  Future<void> createPost({required String kind, required String title,
    required String detail, required String category, required Duration duration,
    String? circleId}) async {
    await client.from('reaches').insert({
      'owner_id': uid, 'kind': kind, 'title': title.trim(),
      'detail': detail.trim(), 'category': category,
      'scope': circleId == null ? 'public' : 'circle', 'circle_id': circleId,
      'expires_at': DateTime.now().toUtc().add(duration).toIso8601String(),
    });
  }
  Future<void> closePost(String id) async =>
      client.from('reaches').update({'status': 'closed'}).eq('id', id).eq('owner_id', uid).then((_) {});

  Future<void> request(String postId, String message) async =>
      client.from('connection_requests').insert({'post_id':postId,'sender_id':uid,'message':message}).then((_) {});
  Future<List<ReachRequest>> requests({bool incoming = true}) async {
    final result = await client.rpc('list_connection_requests', params: {'p_incoming':incoming});
    return (result as List).map((e) => ReachRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  Future<void> answerRequest(String requestId, bool accepted) async {
    await client.rpc('answer_connection_request', params: {'p_request_id':requestId,'p_accept':accepted});
  }
  Future<List<Map<String, dynamic>>> conversations() async {
    final result = await client.rpc('my_conversations');
    return (result as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Stream<List<Map<String, dynamic>>> messages(String conversationId) => client.from('messages')
      .stream(primaryKey: ['id']).eq('conversation_id', conversationId)
      .order('created_at', ascending: true).map((rows) => rows.map((e)=>Map<String,dynamic>.from(e)).toList());
  Future<void> sendMessage(String conversationId, String body) async {
    await client.from('messages').insert({'conversation_id':conversationId,'sender_id':uid,'body':body.trim()});
  }

  Future<List<Map<String, dynamic>>> circles() async {
    final data = await client.rpc('my_communities');
    return (data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String,dynamic>>> discoverCommunities({
      String area = 'country', String category = 'All', String keyword = ''}) async {
    final result = await client.rpc('discover_communities', params: {
      'p_area': area, 'p_category': category, 'p_keyword': keyword.trim(),
    });
    return (result as List)
      .map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }
  Future<void> createCommunity({required String name, required String category,
      required String description, required bool isPublic}) async {
    await client.rpc('create_community', params:{
      'p_name':name.trim(), 'p_category':category,
      'p_description':description.trim(),
      'p_visibility':isPublic?'public':'private',
    });
  }
  Future<void> joinPublicCommunity(String id) async =>
      client.rpc('join_public_community', params: {'p_circle':id}).then((_) {});
  Future<void> createCircle(String name) async =>
      client.rpc('create_circle', params: {'p_name':name}).then((_) {});
  Future<void> joinCircle(String invite) async =>
      client.rpc('join_circle', params: {'p_code':invite.trim().toUpperCase()}).then((_) {});
  Future<void> leaveCircle(String id) async =>
      client.rpc('leave_circle', params: {'p_circle':id}).then((_) {});
  Future<void> deleteCircle(String id) async =>
      client.rpc('delete_circle', params: {'p_circle':id}).then((_) {});

  // Group workspaces require membership, enforced in Supabase RLS/RPC.
  Future<List<ReachPost>> groupPosts(String id) async {
    final data=await client.rpc('reach_group_posts',params:{'p_circle':id});
    return (data as List).map((r)=>ReachPost.fromJson(
      Map<String,dynamic>.from(r as Map))).toList();
  }
  Future<List<Map<String,dynamic>>> groupMembers(String id) async {
    final data=await client.rpc('reach_group_members',params:{'p_circle':id});
    return (data as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }
  Stream<List<Map<String,dynamic>>> groupMessages(String id)=>
    client.from('reach_group_messages').stream(primaryKey:['id'])
      .eq('circle_id',id).order('created_at',ascending:true).limit(120)
      .map((rows)=>rows.map((r)=>Map<String,dynamic>.from(r)).toList());
  Future<void> sendGroupMessage(String circle,String body) async {
    await client.from('reach_group_messages').insert({
      'circle_id':circle,'sender_id':uid,'body':body.trim(),
    });
  }
  Future<List<Map<String,dynamic>>> groupResources(String id) async {
    final rows=await client.from('reach_group_resources').select()
      .eq('circle_id',id).order('created_at',ascending:false).limit(100);
    return rows.map((r)=>Map<String,dynamic>.from(r)).toList();
  }
  Future<void> shareGroupResource(String circle,{
    required String title,required String note,String? url}) async {
    await client.from('reach_group_resources').insert({
      'circle_id':circle,'creator_id':uid,'title':title.trim(),
      'note':note.trim(),'kind':url==null?'note':'link','url':url?.trim(),
    });
  }
  Future<void> removeGroupResource(String id) async =>
    client.from('reach_group_resources').delete().eq('id',id).then((_) {});
  Future<String> rotateGroupInvite(String id) async {
    final value=await client.rpc('reach_rotate_group_invite',
      params:{'p_circle':id});
    return value as String;
  }
  Future<List<Map<String,dynamic>>> callContacts() async {
    final rows=await client.rpc('reach_my_call_contacts');
    return (rows as List).map((row)=>Map<String,dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String,dynamic>>> callHistory() async {
    final data=await client.rpc('reach_my_call_history');
    return (data as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
  }

  Future<List<Map<String,dynamic>>> alerts() async {
    final result = await client.from('alerts').select().eq('user_id',uid)
      .order('created_at', ascending:false).limit(50);
    return result.map((r)=>Map<String,dynamic>.from(r)).toList();
  }
  Future<void> readAlerts() async =>
      client.from('alerts').update({'read_at':DateTime.now().toUtc().toIso8601String()})
        .eq('user_id',uid).isFilter('read_at', null).then((_) {});
  Future<void> blockUser(String id) async =>
      client.from('blocks').upsert({'blocker_id':uid,'blocked_id':id}).then((_) {});
  Future<void> unblockUser(String id) async =>
      client.from('blocks').delete().eq('blocker_id',uid).eq('blocked_id',id).then((_) {});
  Future<List<Map<String,dynamic>>> blockedUsers() async {
    final result = await client.rpc('my_blocks');
    return (result as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<void> report(String targetType, String targetId, String reason, String detail) async =>
      client.from('reports').insert({'reporter_id':uid,'target_type':targetType,
        'target_id':targetId,'reason':reason,'detail':detail}).then((_) {});
  Future<void> deleteAccount() async {
    final user=client.auth.currentUser;
    if(user==null)throw StateError('Sign in before deleting your account.');
    // Supabase Auth deletion cascades table metadata, but Storage files
    // must be removed through the Storage API before the account is deleted.
    final files=await client.from('chat_attachments')
      .select('id').eq('sender_id',user.id).limit(1);
    if(files.isNotEmpty){
      final cleanup=await client.functions.invoke('cleanup-chat-attachments',
        body:<String,dynamic>{});
      final response=cleanup.data;
      if(response is! Map || response['removed'] is! num){
        throw StateError('Unable to delete private chat files. Try again.');
      }
    }
    await client.rpc('delete_my_account');
    await client.auth.signOut();
  }
}

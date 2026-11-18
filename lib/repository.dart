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
  Future<void> magicLink(String email) async =>
      client.auth.signInWithOtp(email: email, emailRedirectTo: AppConfig.callback);
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
  Future<void> updateProfile(Map<String, dynamic> values) async =>
      client.from('profiles').update(values).eq('id', uid).then((_) {});

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
    final data = await client.rpc('my_circles');
    return (data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<void> createCircle(String name) async =>
      client.rpc('create_circle', params: {'p_name':name}).then((_) {});
  Future<void> joinCircle(String invite) async =>
      client.rpc('join_circle', params: {'p_code':invite.trim().toUpperCase()}).then((_) {});
  Future<void> leaveCircle(String id) async =>
      client.rpc('leave_circle', params: {'p_circle':id}).then((_) {});
  Future<void> deleteCircle(String id) async =>
      client.rpc('delete_circle', params: {'p_circle':id}).then((_) {});

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
  Future<void> deleteAccount() async =>
      client.rpc('delete_my_account').then((_) async {await client.auth.signOut();});
}

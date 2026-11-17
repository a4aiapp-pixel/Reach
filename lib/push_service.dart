import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Firebase configuration is an operator-supplied Android google-services.json.
/// ENABLE_PUSH must be true at build time. No privileged FCM credentials go in the app.
class ReachPush {
  static const enabled = bool.fromEnvironment('ENABLE_PUSH', defaultValue: false);
  static bool initialized = false;
  static StreamSubscription<String>? _tokenSubscription;
  static Future<bool> prepare() async {
    if (!enabled) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      initialized = true;
      return true;
    } catch (_) {
      initialized = false;
      return false;
    }
  }
  static Future<void> register(SupabaseClient client) async {
    if (!initialized || client.auth.currentUser == null) return;
    final permission=await FirebaseMessaging.instance.requestPermission();
    if(permission.authorizationStatus==AuthorizationStatus.denied) return;
    final token=await FirebaseMessaging.instance.getToken();
    if(token!=null) await _save(client,token);
    await _tokenSubscription?.cancel();
    _tokenSubscription=FirebaseMessaging.instance.onTokenRefresh.listen((token){
      _save(client,token);
    });
  }
  static Future<void> _save(SupabaseClient client,String token) async {
    final uid=client.auth.currentUser?.id;
    if(uid==null)return;
    await client.from('device_tokens').upsert({'user_id':uid,'token':token,
       'updated_at':DateTime.now().toUtc().toIso8601String()});
  }
  static Future<void> dispose() async {await _tokenSubscription?.cancel();}
}

/// Public Supabase project URL and publishable key — never include service_role keys.
class AppConfig {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ffnhidnnqpamewcepxrr.supabase.co');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable__XkeodycyCMVVaCuLoMFlg_c-aablkm');
  static bool get ready => url.startsWith('https://') && key.isNotEmpty;
  static const callback = 'reachnetwork://auth-callback';
  static const callingEnabled = bool.fromEnvironment('ENABLE_REACH_CALLS', defaultValue:false);
  static const aiEnabled = bool.fromEnvironment('ENABLE_REACH_AI',defaultValue:false);
  static const googleSignInEnabled = bool.fromEnvironment('ENABLE_GOOGLE_AUTH', defaultValue:false);
  static const appName = 'Reach';
  static const legalBase = String.fromEnvironment('LEGAL_BASE_URL', defaultValue: 'https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
}

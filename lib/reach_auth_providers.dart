import 'dart:convert';

import 'package:http/http.dart' as http;
import 'config.dart';

/// Google OAuth is offered only if the live Supabase Auth service advertises
/// the provider. This prevents a non-working button in the Play release while
/// allowing the operator to enable Google in Supabase without a new APK.
/// A successful provider probe does not replace a signed-device OAuth test.
class ReachAuthProviders {
  const ReachAuthProviders._();

  static Future<bool> googleEnabled() async {
    if (!AppConfig.googleSignInEnabled || !AppConfig.ready) return false;
    try {
      final url = Uri.parse('${AppConfig.url}/auth/v1/settings');
      final response = await http.get(url, headers: {
        'apikey': AppConfig.key,
        'accept': 'application/json',
      }).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      final external = decoded['external'];
      if (external is! Map) return false;
      return external['google'] == true || external['google'] == 'true';
    } catch (_) {
      // A failed provider check should never block password/email login.
      return false;
    }
  }
}

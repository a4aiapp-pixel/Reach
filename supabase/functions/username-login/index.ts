// Reach username/password authentication: never exposes account email on a username lookup.
// Deploy without gateway JWT verification: users calling this endpoint are not signed in yet.
// RLS-protected profiles are queried only with backend-only Supabase credentials.
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';

const json = (value: unknown, status = 200) => Response.json(value, {
  status, headers: { 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' },
});
const invalid = () => json({ error: 'Invalid username or password, or email is not confirmed.' }, 401);

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  if ((request.headers.get('content-length') ?? '').length > 8) return json({ error: 'Invalid request' }, 400);

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return json({ error: 'Invalid request' }, 400);
  }
  const username = typeof payload?.username === 'string'
    ? payload.username.trim().toLowerCase() : '';
  const password = payload?.password;
  if (!/^[a-z][a-z0-9_]{2,23}$/.test(username) ||
      typeof password !== 'string' || password.length < 8 || password.length > 256) {
    return invalid();
  }

  const url = Deno.env.get('SUPABASE_URL');
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !secret) return json({ error: 'Authentication temporarily unavailable' }, 503);

  // Both per-username and per-IP limits are applied before user lookup.
  const remote = (request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0] ??
    request.headers.get('x-real-ip') ?? 'unknown').trim().slice(0, 128);
  const admin = createClient(url, secret,
    { auth: { autoRefreshToken: false, persistSession: false } });

  try {
    const { data: permitted, error: limitError } = await admin.rpc(
      'consume_username_login_slot', { p_username: username, p_remote_addr: remote });
    if (limitError) return json({ error: 'Authentication temporarily unavailable' }, 503);
    if (permitted !== true) return json({ error: 'Too many sign-in attempts. Try again later.' }, 429);

    const { data: profile, error: lookupError } = await admin.from('profiles')
      .select('id,suspended').eq('username', username).maybeSingle();
    if (lookupError || !profile || profile.suspended) return invalid();

    const { data: account, error: accountError } = await admin.auth.admin.getUserById(profile.id);
    const email = account?.user?.email;
    if (accountError || !email) return invalid();

    // Gotrue verifies the password itself. No custom password hashing,
    // credential logging, or direct session issuance is implemented here.
    const response = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        apikey: secret,
        authorization: `Bearer ${secret}`,
      },
      body: JSON.stringify({ email, password }),
    });
    if (!response.ok) return invalid();
    const result = await response.json();
    if (typeof result?.refresh_token !== 'string' ||
        typeof result?.access_token !== 'string') {
      return json({ error: 'Authentication temporarily unavailable' }, 503);
    }
    // The client imports the returned session using supabase.auth.setSession().
    return json({ refresh_token: result.refresh_token, access_token: result.access_token });
  } catch {
    return json({ error: 'Authentication temporarily unavailable' }, 503);
  }
});

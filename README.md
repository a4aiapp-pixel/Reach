# Reach — Android social availability network

**Version:** 1.0.0 source candidate (17 November 2026)  
**Objective:** A privacy-conscious, consent-first way to offer or request short-term help.

> **Release status:** GitHub-source candidate, NOT a verified production release. The environment used to produce this archive has no Flutter SDK/Android SDK and no Internet access to install them; therefore a real `flutter analyze`, APK/AAB compilation, device tests, backend integration tests, and Google Play review **have not been performed here**. The included GitHub Actions workflow does these checks when run in GitHub. Publishing still requires real service accounts and operational moderation. No backend credentials or fictitious user data are included.

## Feature inventory

| Area | Included in source | Notes |
|---|---|---|
| Email/password, verification links, password reset | Yes | Supabase email authentication and Android callback |
| Google OAuth sign-in | Yes | Enable Google provider in Supabase; set Google OAuth client credentials |
| Email magic-link sign-in | Yes | Requires email provider and callback configuration |
| Profile, bio, self-declared skills, city and country | Yes | Skills are **not verified** qualifications |
| Find people offering/asking for help | Yes | Full-text substring search + category/type filters |
| Nearby 5–100 km discovery | Yes | Optional low-accuracy GPS, rounded 0.1° on device; no exact GPS upload |
| Discover in city, country, or worldwide | Yes | Server-side filters and visibility access checks |
| Time-limited offers and requests | Yes | 30m/1h/3h/24h/7d; automatic query expiry |
| Public or members-only circle posts | Yes | Invitation code, join/leave/delete |
| Mutual-consent connection requests | Yes | Accept or decline before chat is available |
| Realtime 1:1 text chat | Yes | Private by RLS and gated by accepted connection |
| Activity notifications in app | Yes | Alerts stored by database triggers |
| Background push notifications | **Optional integration** | Firebase Messaging + Edge webhook included; Firebase/backend setup required |
| Report posts/messages/accounts; block/unblock | Yes | Reports need a **human moderator** in the operator backend |
| In-app / web account deletion | Yes | `delete_my_account()` cascade plus `docs/delete-account.html` |
| Light, dark, system theme | Yes | Saves device preference |
| Backend access controls | Yes | Supabase Row Level Security + security-definer functions |
| Server-side anti-spam controls | Partial | Active-post cap, request rate cap, message rate cap; abuse prevention requires ongoing work |
| Verified identity, video calls, payments, advanced safety screening | **Not included** | Requires additional infrastructure and operational safeguards |
| Admin moderation panel | **Not included** | Use Supabase Dashboard / included moderation SQL runbook |
| Production legal documents and support | **Owner must finalize** | Drafts and web deployment files included |

## Getting started in GitHub — shortest path

1. Create a **new private GitHub repository** (the project contains no credentials) and upload the files from this archive to its root.
2. In [Supabase](https://supabase.com), create a project and obtain its **Project URL** and **publishable key** (never the `service_role`/secret key for Android).
3. Open Supabase SQL Editor and execute each migration **in order**:
   - `supabase/migrations/202611170001_reach.sql`
   - `supabase/migrations/202611170002_hardening_push.sql`
   - `supabase/migrations/202611170003_circle_management.sql`
4. Under Supabase Authentication: enable **email/password**, set email confirmation and email-delivery limits appropriate for production, and allow `reachnetwork://auth-callback` in **Redirect URLs**. For Google login, enable its provider with valid Google OAuth web client ID/secret, configure callback from Supabase, and allow the same app redirect URL.
5. Set the GitHub repository **Settings → Secrets and variables → Actions** secrets listed in the next section.
6. Run **Actions → Android - analyze, test, APK and AAB → Run workflow**. The `validate` job generates the Android scaffold on the GitHub runner, analyzes/tests the app, and compiles a **debug configuration APK**. `production` requires complete release secrets and produces a **signed APK and AAB** as workflow artifacts.
7. Complete the human release checks below and test the backend with two or more real accounts before submitting to Play.

### Required GitHub Actions secrets

| Secret | Purpose |
|---|---|
| `SUPABASE_URL` | `https://PROJECT.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Public project publishable/anon key, **not service_role** |
| `SUPPORT_EMAIL` | Working public support email |
| `LEGAL_BASE_URL` | Published URL of the `docs` legal pages, without trailing `/` |
| `PLAY_KEYSTORE_B64` | Base64 of your self-created Android upload keystore, stored privately |
| `PLAY_KEYSTORE_PASS` | Upload keystore password |
| `PLAY_KEY_ALIAS` | Upload key alias |
| `PLAY_KEY_PASS` | Upload key password |
| `GOOGLE_SERVICES_JSON_BASE64` | **Optional** base64 Android Firebase `google-services.json` for push notifications |

Generate upload signing key **once** and back it up securely; losing it can complicate future release updates:

```bash
keytool -genkeypair -v -keystore upload-key.jks -keyalg RSA -keysize 3072 \
  -validity 10000 -alias reachupload
# Linux: base64 -w0 upload-key.jks
# Windows PowerShell: [Convert]::ToBase64String([IO.File]::ReadAllBytes('upload-key.jks'))
```

If no secrets are configured, `validate` still compiles a **nonfunctional setup screen**. It is **not** a deployable social network. `production` intentionally refuses to generate a Play candidate without the backend/legal/signing secrets.

## Run locally on Windows

Install Flutter **3.50.0 stable**, Android Studio, Android SDK Platform 36 and JDK 17. In PowerShell:

```powershell
flutter create --platforms=android --project-name reach_network --org app.reachnetwork .
python tools/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

To build local release, provide signing file `android/key.properties`, keystore `android/upload-key.jks`, set `REACH_SIGNING_ENABLED=1`, run `tools/prepare_android.py` again, and use `flutter build appbundle --release` with the four `--dart-define` parameters shown in the GitHub workflow. Prefer GitHub Actions for reproducible signed builds.

**Build application ID:** `app.reachnetwork.reach_network` generated by `flutter create`. Replace with an identifier you own **before the first Play publication**, and keep it stable afterwards. The product name “Reach” and application ID have not undergone trademark or Play package-name availability review.

### Enable optional Firebase push notifications

1. Create a Firebase project. Add an Android app whose package name matches the generated `applicationId`.
2. Download its `google-services.json` and store a base64 version as `GOOGLE_SERVICES_JSON_BASE64` in GitHub Actions secrets. Never commit it unnecessarily.
3. Google Play build workflow automatically adds Google Services Gradle plugin and sets `ENABLE_PUSH=true` when this secret exists.
4. Generate Firebase service-account credentials for server-side FCM HTTP v1. Put the JSON in Supabase Edge Function secret `FCM_SERVICE_ACCOUNT_JSON`, **never in the app**.
5. Deploy `supabase/functions/send-push/index.ts` as the Supabase Edge Function `send-push` with `verify_jwt=false`. Configure `REACH_WEBHOOK_SECRET` (random long value) and `SUPABASE_SERVICE_ROLE_KEY` as function secrets.
6. Add a Supabase **database webhook** for `public.alerts` INSERT to `https://PROJECT.supabase.co/functions/v1/send-push`, with header `x-reach-hook: <same secret>`. The function rejects calls that lack that secret.
7. Test the system on two real phones, both with notifications allowed, before marketing background notifications as functional.

The FCM function authenticates as the server, fetches canonical alert data, checks the recipient's notification preferences, and sends to registered device tokens. FCM push delivery depends on Firebase and Edge Function quotas; it is not an entirely offline or guaranteed-free service.

### External privacy, terms and account deletion pages

Publish the `docs/` directory using **GitHub Pages (Deploy from branch `/docs`)** or another HTTPS host. Copy `docs/config.example.js` to `docs/config.js`, replace all placeholders with the **public** Supabase details, actual operator name and support address. The `docs/delete-account.html` page lets members authenticate and invoke the same permanent deletion RPC, including Google sign-in if configured. Add its full HTTPS URL to Play Console's account-deletion field.

**Do not publish placeholders as your final privacy policy or terms.** Have the legal operator complete these documents, data retention statements and jurisdictional requirements. OAuth must also allow the website deletion-page redirect URL.

## Google Play readiness checklist

- [ ] Choose and check a unique package name and app brand; use an original icon and screenshots.
- [ ] Ensure the app **targets API level 36**, required for new mobile apps in 2026; the included Android preparation script applies it.
- [ ] Configure email deliverability (the Supabase default shared SMTP is not suitable for scaled production).
- [ ] Configure Google sign-in credentials, OAuth redirect allowlist, and callback.
- [ ] Run migrations, review RLS and conduct authorization tests from more than one account.
- [ ] Configure moderated reporting workflow; staff must actively review abuse reports.
- [ ] Make a moderation response policy for harassment, fraud, dangerous meetups and banned users; document escalation processes.
- [ ] Enable push service or explain clearly that background push is unavailable.
- [ ] Publish real privacy policy, community rules and external account deletion URL.
- [ ] Complete Play Console Data safety, content rating, audience/age, account deletion, and store listing.
- [ ] Test accessibility, small screens, slow networks, offline error messages, GPS denied state, sign-in, deletion and sign-out.
- [ ] Generate and preserve a release upload key; check signed AAB on Play internal test track.
- [ ] Do independent security, penetration, performance and content-abuse testing before public launch.
- [ ] Prepare launch customer support, terms enforcement and a plan for database/billing quotas.

## Technical notes and limitations

- The network requires a hosted backend; **zero ongoing cost cannot be guaranteed** for any social product at scale. Supabase and Firebase may have free allowances subject to rate limits/quotas, which should be checked during setup.
- Nearby location is rounded to `0.1°` before upload (~11 km of latitude, variable longitude); the server uses approximate distance and does not expose coordinates in discovery results. Do not promise precise street-level proximity.
- Posts expire at the database-query level, but old posts remain stored until they are closed/deleted; add a retention job and age-based pruning as part of operating a mature service.
- The app currently provides **English** user interface text only. International discovery is independent of interface localization.
- There is no identity or qualifications verification. A member's skills are self-declared.
- Messaging supports **plain text**, not attachments, voice/video calling, or end-to-end encryption. Backend-level access restrictions are **not equivalent to E2EE**.
- Reports and suspensions exist in the backend, but the human moderation process and operator must be in place before broad publication.
- The static web deletion page loads `supabase-js` from a CDN; account owners should review dependency/CDN hosting before production.
- The app's account deletion RPC permanently deletes `auth.users` and cascades relevant app data. This is non-recoverable; review any legal data retention duties.
- Potential race conditions, migrations and integration behavior are not fully validated until deployed against real Supabase/Firebase instances and tested on devices.

## Source layout

```text
lib/                       Flutter Android app, screens, repository, config, optional push
supabase/migrations/       SQL schema, RLS, discovery RPCs, circles, deletion, push tokens
supabase/functions/        Firebase HTTP v1 push sender / secured database webhook
docs/                                Privacy / ToS draft and web account deletion page
tools/prepare_android.py   Generated Android manifest, API 36 and Gradle signing settings
.github/workflows/         Automated CI diagnostics + signed Android APK and AAB builds
test/                      Basic model unit tests
supabase/admin/            Moderator dashboard SQL runbook
```

## Ownership and licensing

This is a newly authored source candidate for your project. Review package names, trademarks, licensed dependencies, third-party terms, and all Play content policies before distribution.

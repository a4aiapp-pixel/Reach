# Reach — 360° release audit and Play launch gates
Review started: 18 November 2026 · Repository: a4aiapp-pixel/Reach
Status: **PRE-RELEASE / NOT APPROVED FOR PLAY PRODUCTION**

## Evidence and scope
- Inspected Flutter UI/auth/data layers, Supabase schema, migrations, RLS advisories,
  Edge Functions, CI workflows, legal webpage stubs and the project README.
- Supabase Reach project: active. Hosted SQL migrations present, plus unique-username
  migration and deployed username-login Edge Function.
- Email confirmation was successfully recorded for the initial registered test user.
  The first confirmation link redirected to localhost:3000: a **real UX defect**.
- No physical-device QA, performance profiler results, professional penetration test,
  production moderation dry run, reviewer sign-in test, Play pre-launch report,
  store certification, or final device accessibility audit has been performed.
- CI results for current HEAD and signed store artifacts must be established
  separately. A successful compile is **not** proof of production readiness.

## Gate ledger

| Dimension | Observed | Remaining release gate |
|---|---|---|
| Android/API compliance | Android generation script targets API 36 | Inspect generated manifest; validate Play bundle in Console |
| Installation/build | GitHub workflow compiles universal/ARM64 APKs with Flutter analysis/tests | Current HEAD must pass; signed production Android App Bundle required |
| Authentication | Supabase email/password, confirmation links, magic link, recovery; new username flow and app resend/OTP fallback | Resolve external URL allowlist and localhost redirect; test wrong/expired/reused tokens, both login paths and recovery |
| Google sign-in | Source calls Google OAuth | Provider is **disabled**; Google Cloud OAuth client, consent screen, callback and redirect need owner configuration |
| Username security | Unique lowercase username, server-side identifier resolution and per-handle/IP throttling | Validate rate limits with permissioned test accounts, password guessing resistance and Google-account migration |
| Permissions/privacy | Approximate coordinates optional, user consent screens and stored-RLS policy | Review location rounding against radius claims, Android runtime rationale, consent revocation, denied permission handling |
| UGC/community safety | Report and block endpoints and basic limits exist | Operational moderation dashboard, response owners, audit trail, abuse triage and user appeal process must actually run |
| Child safety | Source states 18+ and prohibits exploitation | Check applicability of Play Social/Child Safety standards; publish policies, contact and reporting process |
| Backend access control | RLS enabled; Supabase advisor flags privileged functions with SECURITY DEFINER | Pen-test cross-account reads/writes, attachments, relationships; review each definer's internal auth checks |
| Messaging | Private text chat with accepted connection gating in source | Test unauthorized message access, blocking mid-chat, offline/reconnect behavior and notification delivery |
| Account deletion | In-app delete RPC + web deletion page source | Publish functional external HTTPS page; verify deletion across auth, messages, posts, token stores and backups/retention |
| Email deliverability | Default Supabase shared mail used in early tests | Configure robust SMTP/verified domain and abuse controls before broad audience |
| Documentation | Draft terms/privacy/deletion pages exist | Replace placeholders with real operator identity, jurisdiction, retention and support contacts; host over HTTPS |
| Data safety & disclosures | App collects registration, messages, region, optional approximate location | Declare actual processing, sharing, retention, deletion, encryption and SDK usage in Play Console |
| Device UX/accessibility | 10 curated design systems implemented; Flutter responsive layouts | Device-matrix checks: small phone, tablets, font scaling, reduced motion, screen reader, RTL, dark variants |
| Performance | Discovery search debounce and pagination-like list architecture | Cold-start/scroll latency, data transfer, battery, slow-network and offline instrumentation still required |
| Security/cost | Public client key only; service role stored server-side; free-tier goal | Monitor auth abuse, secret rotation, quotas, logs/retention; free usage is not infinite |
| Stability/reliability | GitHub CI analyze/unit tests, reconnect design in progress | Integration, crash/ANR, background delivery, airplane-mode, low-memory, quota failure tests |
| Play listing | Store listing draft exists | Original marketing screenshots, verified brand/package name, logo, privacy URL and truthful declarations |
| Distribution/signing | APK workflow exists, no established signed AAB or Play Console account | Secure upload key, verified developer account, internal test and (if required) 12 testers/14 days closed testing |

## Critical risks
1. **BLOCKER: OAuth and verification URL configuration.** Google provider not enabled.
   Supabase Site URL currently uses localhost:3000. Add
   `reachnetwork://auth-callback` to redirect allowlist, set valid public Site URL,
   and configure Google's OAuth client and callback if Google login remains visible.
   Without this, reviewers may fail the login flow.
2. **BLOCKER: publishable legal identity.** Existing `docs/config.example.js`,
   privacy, terms and deletion content are scaffolds, not real public commitments.
3. **BLOCKER: operational trust & safety.** Social apps must continuously moderate
   objectionable user-generated content. Code-only report/block is not enough.
4. **BLOCKER: signing/distribution.** No verified signed AAB or authorized Play
   Console upload. Do not use debug-key-signed test APK for production.
5. **BLOCKER: independent testing.** Do not infer functional quality from static
   compilation. Authenticate with at least two legitimate test accounts and
   complete multi-device privacy/authorization tests.

## Standard release lifecycle (no fictitious accounts)
- Audit source/security and fix CI/lint/test failures.
- Provision real operator contact, Google OAuth and email delivery.
- Publish HTTPS privacy, terms, community rules and deletion endpoints.
- Prepare unique verified application ID and secure upload keystore.
- Generate signed AAB with pinned release version and check Play pre-launch reports.
- Upload to internal testing and exercise test cases with real consenting users.
- Complete Play Data safety, age/content rating, account deletion and safety declarations.
- Where applicable, run Play's closed test (12 opted-in testers for >=14 days).
- Submit production only after the critical release gates pass.

## Official policy sources (checked 18 Nov 2026)
- Google Play target API (new apps API 36): https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play user-generated-content and moderation requirements: https://support.google.com/googleplay/android-developer/answer/18265346
- Google Play user data/privacy/deletion: https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Supabase redirect URL configuration: https://supabase.com/docs/guides/auth/redirect-urls
- Supabase login/OTP: https://supabase.com/docs/guides/auth/passwords

## Release principles
- No paid charges without owner authorization.
- No fake accounts, synthetic testimonials, fabricated downloads or false reviews.
- No exposure of service-role credentials in client, logs, screenshots or repository.
- Mark every artifact **test**, **candidate**, or **production** accurately.

# Google Play Console — Reach launch package (operator checklist)
Updated 18 Nov 2026. Release status: **NOT SUBMITTED**. The current signed-AAB handoff, live policy URLs and current 1.0.5 version are in [PLAY_CONSOLE_HANDOFF_2026_11_18.md](PLAY_CONSOLE_HANDOFF_2026_11_18.md). This older checklist is retained as a conservative operational gate ledger.

## Store text
**App name:** Reach

**Short description (under 80 characters):**
Offer help, request support, and connect with your community.

**Full description (draft; finalize after physical-device validation):**
Reach helps people exchange skills and support within trusted communities.

Find help when you need it or offer your time and knowledge to others.
Browse community requests, explore practical categories, and connect by mutual
agreement. Stay in control of your profile, notifications and privacy choices.

Core capabilities:
- Share or discover offers of help and requests for support.
- Connect by permission, then communicate inside the app.
- Organize smaller invitation-based circles.
- Report or block unwanted interactions.
- Choose from ten distinctive appearance themes.
- Use Reach Assist's free offline smart tools to draft messages, check
  common scam warning signs and browse useful English–Urdu phrases.

Reach Assist's free tools are deterministic, **not generative AI**, and do
not send their input to an AI provider. It cannot verify users, find live
matches, or guarantee safety.

Location sharing is optional and approximate. Use public spaces for initial
meetups and do not share passwords or sensitive financial details.

The app is provided for lawful community connections, not emergency
response or guaranteed professional services.

*Do not add file-sharing/voice/video/Google OAuth claims until independent
release/device tests and required provider configuration are completed.*

## Operational release gates
- [ ] Real Play Console developer identity verified (no fake accounts).
- [ ] Google Play developer registration payment **only after approval**;
      do not incur charges automatically.
- [ ] Confirm package ID, app signing enrollment, persistent private upload key,
      higher monotonically increasing versionCode, and signed production AAB.
- [ ] Public HTTPS privacy policy, operator identity, support email, deletion
      instructions and hosted contact page are live and factually accurate.
- [ ] Real email authentication/confirmation with production SMTP and proper
      Supabase Site URL/deep-link redirect; Google OAuth enabled only if ready.
- [ ] Data safety form covers user-generated content, approximate location,
      uploads, contacts and any analytics/SDKs actually shipped.
- [ ] Production UGC moderation operator, report/block process and appeals.
- [ ] Play age rating, target audience, child-safety contact and app access
      instructions for reviewers.
- [ ] Real-device tests of permission denial, offline, memory pressure, theme
      changes, login, deletion, and invitation/chat privacy.
- [ ] If personal developer account requires mandatory closed testing,
      obtain **real opt-in testers**, not fake accounts; follow Play Console's
      current displayed rules.
- [ ] Roll out to internal testing and address Play pre-launch warnings.
- [ ] Do not enable unverified voice/video calls, cloud AI, subscriptions or
      advertisements in production.

## Recommended free-first launch defaults
- Local Reach Assist always enabled; cloud inference disabled.
- Google sign-in disabled until OAuth credentials and provider are configured.
- Audio/video calling disabled until two-device tests and TURN readiness.
- Business registration may accept interest, but no paid subscriptions,
  transaction fees or sponsored impressions are activated.
- No paid service provider keys, new subscriptions, TURN expenses or ads
  without explicit owner consent.
- Do not publish sample user profiles, synthetic ratings, fake downloads,
  fictitious support details or unverifiable safety claims.

## Artwork and metadata still needed
- Genuine launcher icon (512×512 Google Play asset), feature graphic (1024×500),
  real app screenshots from tested devices, privacy/help URL, developer name,
  support email, developer contact details, declaration forms.
- For screenshots: demonstrate real discovery, permissioned chat, themes,
  consent, offline Reach Assist and business-interest page as actually shipped.

## Play Console steps after prerequisites
1. [Play Console](https://play.google.com/console) → All apps → Create app
   using the actual developer account.
2. Upload the signed AAB to the internal testing track, fill app content,
   data safety, privacy/deletion, rating, audience and store listing.
3. Enroll permitted real testers and complete Play's required test period,
   then request production access and submit for review.

## Evidence
Code and release-gate evidence:
- `docs/RELEASE_AUDIT_2026_11_18.md`
- `docs/REACH_ASSIST_FREE_FIRST.md`
- `docs/VOICE_VIDEO_CALLS_RELEASE_GATE.md`
- `.github/workflows/reach-apks.yml`

Do not confuse successful APK compilation with published Play listing.

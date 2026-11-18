# Reach feature activation and launch gates

This matrix distinguishes **source present**, **backend configured**, **compiled**, **device-tested**, and **approved for production**. Never advertise a feature as live on the basis of source code or a successful build alone.

| Feature | Source | Default public build | Requirements to enable |
|---|---|---|---|
| Email/password | Present | Enabled | Fix Auth callback landing; verify Supabase email confirmation and resend flow; real Android account test |
| Google sign-in | OAuth client present | Disabled | Configure Google provider in Supabase Auth, Google Cloud OAuth consent and Android redirect; verify signing SHA and callback on actual signed build; build with ENABLE_GOOGLE_AUTH=true |
| Voice/video calls | WebRTC foreground implementation | Disabled | Apply call migrations; enable REACH_ENABLE_CALLS=1 in Android preparation AND ENABLE_REACH_CALLS=true in Dart build; test permissions, both endpoints, blocks, disconnect/reconnect and background behavior on two real devices; STUN-only has no guaranteed NAT traversal; TURN credentials/service required for broad reliability |
| Remote notifications | Firebase client/token registration | Disabled | Provision app-matched google-services.json and Firebase credentials securely; enable REACH_ENABLE_PUSH=1 in Android preparation AND ENABLE_PUSH=true in Dart build; deploy and authorize send-push server function, verify FCM token delivery and real-device foreground/background delivery; request notification permission contextually |
| Nearby discovery | Approximate coarse location | Optional | Verify permission denial path and no precise location uploads |
| Chat/attachments | Present | Enabled | Verify 2-account access, RLS, storage cleanup, file limits, report/block |
| Groups/circles | Present | Enabled | Verify membership, moderator controls and spam limits |
| Reach Assist | On-device rules | Enabled | Never describe as generative AI |
| Cloud AI | Feature-gated | Disabled | Explicit approved provider/cost budget, abuse quotas, privacy disclosures, no unapproved charges |
| Payments | Backend groundwork | Disabled | Legal/commercial, billing, consumer disclosure and Play Billing compliance |

## Safe release sequence

1. Fix email confirmation landing and branded email template in live Supabase Auth settings; test Android callback and web fallback.
2. Validate Google OAuth consent and credentials and use a signed internal-test build.
3. Configure Firebase credentials and send-push securely; verify device delivery.
4. Test calls on two devices and at least two distinct mobile networks; retain disabled status for production if NAT traversal fails.
5. Build APKs and signed AAB with feature flags matching actual configurations, audit compiled permissions, complete Play Data Safety and app-content disclosures.
6. Complete real-device security, child-safety, moderation, account-deletion and abuse tests; submit to internal testing before public release.

## Release configuration notes

Dart switches: `--dart-define=ENABLE_GOOGLE_AUTH=true`, `--dart-define=ENABLE_REACH_CALLS=true`, `--dart-define=ENABLE_PUSH=true`. Android manifest switches: `REACH_ENABLE_CALLS=1` and `REACH_ENABLE_PUSH=1` when running `tools/prepare_android.py`.

**Important:** Do not enable Dart flags alone: calling and notifications also require corresponding Android manifest permissions and verified backend/provider configuration. Do not commit Firebase private credentials, Supabase service role keys, FCM server credentials or Play signing secrets to the repository.

**Current decision:** Keep optional unverified features disabled in the public Play build. Enable them for internal QA only after their setup gates are met. Free STUN is not a substitute for TURN and Firebase's free-tier eligibility does not imply unlimited free service.

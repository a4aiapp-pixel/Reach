# Reach — Google Play submission handoff (18 November 2026)

**Status:** Signed internal-test release candidate in preparation. NOT uploaded to Play, NOT approved for production. This file does not authorize charging a payment method, and all Store submissions require the developer's verified account.

## App identity and public links

- Display name: **Reach – Community Help**
- Package/applicationId expected from Flutter generator: `app.reachnetwork.reach_network` (verify from the generated signed AAB/Play Console).
- Launch version: `1.0.4` / versionCode `5`; later updates MUST increment versionCode and reuse the persistent upload key.
- Android target: API 36 (Android 16).
- Category: Social (community help); 18+ self-declared eligibility, not dating or matchmaking.
- Primary language: English. In-app English/Urdu phrases are limited prewritten utilities, not full translation.
- Website and published support hub: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/index.html
- Privacy policy: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/privacy.html
- Community rules: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/terms.html
- Child safety policy: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/child-safety.html
- Web account deletion: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/delete-account.html
- Operator contact/safety reports: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/contact.html

Live URL and web deletion need browser sign-in and real-account tests before submitting their URLs in Play Console.

## Store listing copy

**App name**: Reach – Community Help

**Short description**: Offer help, request support, and connect with your community.

**Full description**:

Reach makes it easier to offer practical help, request support, and connect with people in your community.

Discover time-limited offers and requests. Explore by city, country, or approximate nearby area when you choose to share location. Join public topic groups, start groups from templates, create invitation-based circles and send connection requests before starting a private conversation.

Stay in control with account privacy choices, blocking, reporting, and account deletion. Select from ten app themes and use free Reach Assist smart tools for help drafting messages, identifying basic scam warning signs, and looking up fixed English–Urdu phrases.

Reach Assist's included free tools are rule-based and work on device. They are not a generative AI chatbot. Profile details and credentials supplied by other members are not independently verified.

For adults 18 and older. Meet in public places, never share passwords or payment codes, and report suspicious activity. Reach does not provide emergency services or guarantee the safety or availability of third-party help.

**Do not advertise:** Google login (disabled), general-purpose cloud AI, assured background push delivery, voice/video calls (disabled), paid services, guaranteed verified identity, comprehensive malware scanning, end-to-end encryption, or guaranteed live location accuracy.

## Policy and Data safety questionnaire — audit truthfully before submission

- The app allows account creation and in-app deletion; a publicly accessible self-service deletion page is deployed. Confirm from a real account that storage cleanup and cascading deletion work.
- Account email (authentication), username/display name and optional profile information are stored in the Reach Supabase backend.
- Posts, connection requests, invitations/circles, messages and user-selected files (photos, audio, video and documents) may be stored according to actual user actions. Private chat attachments have a 6 MiB file limit; no blanket malware-scan guarantee.
- Nearby location is strictly optional; device latitude/longitude are rounded to approximately 0.1-degree grid before backend upload. Disclose approximate location, collection and intended purpose; never claim precise coordinates are uploaded by default.
- Abuse reports, blocks, account security, and support-contact requests are stored. Public web contact uses network-hash anti-spam controls.
- Information is processed by Supabase and potentially stored/processed internationally. Firebase Messaging wiring exists but remote push is not enabled in the standard default release; reassess when activated.
- No ads, in-app billing, subscriptions, default remote generative AI, or cloud AI provider charges are enabled.
- The application uses HTTPS for client/server transport and database access controls but private chat is not claimed end-to-end encrypted.
- Google Play declarations on collection, sharing with processors, retention and deletion, device identifiers, app activity, security practices and advertising must be completed based on the actual binary/SDK inventory and on-device findings. Do not blindly mark "no data collected."

## Required operator actions — not automatable with current access

1. **Verified developer/publisher identity, jurisdiction and contact email**: the legal operator must supply and approve details. Never invent a publisher or use an unapproved personal address. Publish them consistently in the official Play developer listing, policy and child-safety contact.
2. **Google Play Console account**: open https://play.google.com/console, complete developer verification and any registration payment only with owner approval. Store listing and final declarations must be entered under that account.
3. **Supabase Auth**: in https://supabase.com/dashboard/project/ffnhidnnqpamewcepxrr/auth/url-configuration replace localhost:3000 Site URL with the actual public support/policy page, allowlist `reachnetwork://auth-callback`, and verify email confirmation, password reset and magic-link return to the Android app. Set a production-capable SMTP/email provider before broad user acquisition.
4. **Safety operations**: appoint a real moderator and child-safety point of contact; check `public.reports` and `public.reach_support_inbox` regularly in the Supabase dashboard, respond to actionable reports, log decisions, and handle critical child safety incidents with appropriate legal escalation. No unattended social launch.
5. **Device tests**: use two real verified accounts on at least two Android devices to test sign-up/verification, connection acceptance, messages/files, report/block, account and attachment deletion, optional permissions, network switching/offline and responsive UI. Capture truthful screenshots from that running app.
6. **Play store assets**: provide actual screenshots, 512×512 launcher icon and a 1024×500 feature graphic consistent with shipped UI. No mock user claims presented as true.
7. **App Content**: complete policy attestations, age/target-audience declarations (not a children’s app), IARC rating, UGC and Child Safety declarations, data safety and verified reviewer access; place the signed AAB into **internal testing** first.
8. **Testing requirement**: if the specific developer account is subject to Play's closed-testing prerequisites, recruit legitimate consenting opt-in testers for the required period; do not fabricate testers or reviews.

## Release workflow

GitHub Actions `.github/workflows/reach-apks.yml` compiles a universal release-mode APK, ARM64 APK and, when the four existing `PLAY_KEY*` secrets are present, a separate signed Play internal-test **AAB** using the SAME upload key. The AAB no longer needs unnecessary additional Supabase URL, public key, legal base and operator-email secrets: those are separate readiness checks. The public Supabase publishable key is intentionally a client-safe value. No service-role key is committed.

For download use the individual artifacts shown in the latest successful workflow: https://github.com/a4aiapp-pixel/Reach/actions. Repository is private, so GitHub login may be required.

**Not yet done**: Google Play registration/submission, signed-AAB Play validation, contact identity, real device QA, confirmation of Auth URL settings and ongoing human moderation. Signed compilation is not Play approval.

**Approved Play icon:** The three connected-person figures in a location pin supported by a hand. Download its versioned 512×512 PNG from the corresponding successful GitHub Actions v1.0.4 branding artifact. App name remains **Reach**.

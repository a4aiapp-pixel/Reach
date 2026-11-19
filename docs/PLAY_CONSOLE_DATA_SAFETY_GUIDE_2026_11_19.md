# Reach v1.0.7 — Play Console Data safety and App content worksheet

**Prepared:** 19 November 2026. **Status:** draft grounded in current code and database; NOT submitted to Google Play. Final declarations must be checked against the exact signed AAB and real user journeys. Do not claim to be approved by Google or to have passed third-party audits.

## Application and publisher

- App display name: **Reach** (exact owner-selected name), package `app.reachnetwork.reach_network`.
- Default category: Social / community help (not a dating service); intended audience **18+**.
- Contact email, verified legal publisher, moderation officer and child-safety point of contact: **NOT SUPPLIED**. Do not fabricate them.
- Current icon: approved three-person location-pin artwork. Feature graphic: 1024×500 PNG prepared separately. Real on-device screenshots: **pending**.
- Google login: conditional on the provider actually being configured in Supabase. Cloud AI, advertisements, payments and Firebase background push: **disabled**. Voice/video calls: **enabled for opt-in internal QA builds only**, with camera/mic permissions, STUN-only limitations and no device/network acceptance results yet. Do not advertise them as reliable production calls.
- No artificial community accounts, fabricated engagement, purchasing reviews or fabricated Play testers.

## Information Reach uses and why

| Play Data safety category to consider | Current real usage | User choice / important qualifiers |
| --- | --- | --- |
| Personal info — email address | Supabase Auth registration, login, account recovery | Required to operate an account |
| Personal info — name / user IDs | Username, display name, account ID | Username/display name collected during signup |
| Personal info — other information | Profile bio, city, country, skills, chosen interests and profile visibility preferences | People-search enrollment is OFF by default; accepted contacts may see private profile details |
| Approximate location | Optional Android location consent, rounded coordinates (0.1°) for nearby discovery | **v1.0.7 only declares coarse foreground location**; verify live behavior before final declaration |
| Messages | Invitation requests and accepted private conversations/messages | Sent only when used; not end-to-end encrypted; direct member requests require approval |
| Photos / videos / audio | Historic chat attachments may exist; new media uploads are blocked until dependable safety screening | Camera/mic requested only for accepted, foreground voice/video calls in QA build; do not claim content scanning |
| Files and documents | User-selected documents in private, accepted chats | 6 MiB per file; may contain embedded unsafe media; not comprehensively scanned |
| App activity | Posts/offers/requests, circle membership, connection activity, safety reports and blocks | Necessary for discovery, matching, moderation and abuse prevention |
| Diagnostics/device IDs | SDK/platform metadata may be processed by Supabase, Android or optional compiled SDKs | Audit exact app and SDK behavior; do **not** automatically declare this absent |
| Other user-provided content | Public group names/descriptions, posts, interest categories and opted-in people directory | Minimal name/username/city/country appear only with consent; bio and skills are public only if selected or for accepted connections |
| Safety/support information | Report reason/detail, contact email and message via web support form | Operator-only reporting and spam-limiting hash for web support |

**Age handling:** Birthdate is submitted transiently to check the 18+ threshold and is not retained; an adult self-attestation timestamp is retained. This is not documentary or identity verification. Account-created adult-only gates must be device tested.\n\n**Calling:** The QA AAB uses RECORD_AUDIO and CAMERA and foreground WebRTC signaling. Both adults must opt in and accept a connection; STUN-only cannot guarantee all mobile networks. Calling metadata and possible peer IP exposure must be reflected in the live privacy policy.\n\n**Moderation:** High-confidence text patterns and rate limits reject selected prohibited promotion/sales; false negatives/positives remain possible and reports need a human moderator. No automatic visual CSAM/NSFW detector exists; newly uploaded media are restricted.\n\n**Transport and storage:** The normal client/server path is HTTPS. Row-level security and private storage exist for data access; do not claim end-to-end encryption or unconditional malware scanning. Supabase processes the app's backend data.

**Sharing vs processing:** Carefully distinguish data processed by Supabase as service provider from user-visible sharing with other community members. Public posts and public-group metadata may be displayed to signed-in participants. Verify Google Play's precise definitions and answer for each actual data type.

**Deletion:** The in-app account deletion and public self-service deletion portal exist. A real test must confirm authentication, attachment cleanup, user deletion, and retention behavior before marking data deletion compliant. Some legally required moderation/security records and routine backup timing may need further documented exceptions. Review privacy policy against actual retention.

## Play App content declarations

- Privacy policy: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/privacy.html
- Web account deletion: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/delete-account.html
- Community rules: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/terms.html
- Child safety policy: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/child-safety.html
- Support/safety reporting: https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/contact.html
- App access for reviewers: account registration/verification required to view member features; provide real reviewer access according to Play Console. Never fabricate a verified account or share passwords in repository files.
- Content rating: complete Google's IARC questionnaire honestly for member generated content, chat and discussion. Do not choose a rating without the questionnaire.
- Target audience: 18+ is stated by app policies. Verify signup age declaration and real Google Play audience settings.
- User-generated content: reports/blocks are implemented, but a **human operator and operational response process** are required. App is not a substitute for emergency reporting.
- Child safety: must identify the real responsible contact, publish standards and comply with legal reporting and moderation obligations.
- Device permissions: inspect the signed `PLAY-PERMISSION-AUDIT.json` from v1.0.7; **no precise location, background notification or broad storage permission should appear; CAMERA and RECORD_AUDIO are expected for the opt-in calling QA variant**. APK/device-side confirmation is still required.

## Unresolved gates

1. Verify legal developer identity and working support/child-safety contact.
2. Confirm Supabase Auth URL allowlist, production SMTP delivery and leaked-password protection. Current Supabase security advisor warns that breached-password protection is disabled.
3. Test sign-up, email OTP/password recovery, username sign-in, chat attachments, account deletion, report/block and optional location on **two distinct real accounts/devices**.
4. Capture truthful screenshots of the actual running Android UI; do not submit invented or mock screens as product screenshots.
5. Upload the signed AAB to Play Console internal testing, complete all declarations and check Play Pre-launch report.
6. If the developer account is subject to closed-testing prerequisites, recruit **12 genuine consenting, continuously opted-in testers for at least 14 days** before applying for production. Do not use fake accounts or paid review schemes.
7. Maintain human review of `public.reports`, `public.reach_support_inbox` and case decisions; establish retention/deletion procedures.

**Source of truth:** the exact signed Reach AAB and actual live app. A completed CI build is not Play authorization.

**People directory:** All profiles default to hidden and private, with calling disabled. Members can independently opt in to people discovery, public bio/skills, and calls. Two-device account tests are mandatory.\n\n**Country/city autocomplete:** Static GeoNames data is bundled in the app. Searching location names does not call a remote autocomplete or geocoding service, and does not request device location. Optional nearby location permission is proposed from a first-use explanation after verified account/profile setup and can be skipped. File attachments use the system picker, not broad storage access.

# Reach v1.0.2 — release status (18 November 2026)

- **Android:** API 36; Flutter 3.50 Android app; source available in this repository.
- **Signed APKs:** previously verified for v1.0.1 (universal and ARM64) using the protected upload key.
- **New target:** v1.0.2+3 signed APKs and AAB must pass the new workflow. Check actual GitHub Actions results before making release claims.
- **Backend:** Reach Supabase live project has RLS, abuse reports, call signaling feature flags and verified child-safety reporting categories; external HTTPS legal portal and support intake deployed.
- **Public policies:** https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/index.html (independent smoke tests and human legal review are still required).
- **App feature flags:** optional cloud AI, Google OAuth, voice/video calls, remote push and charging remain off by default.
- **Not completed:** Google Play developer account verified contact, Console upload and policy declarations, multi-device QA, support inbox/child-safety moderation staffing, email verification redirect/SMTP production readiness, Play review and rollout.

Release handoff: `docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md`. Never misrepresent an internal-test AAB or APK as Play-approved or published.

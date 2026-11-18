# Reach v1.0.5+6 — Google Play preparation (19 November 2026)

- **Brand:** Reach and the approved three-person community location-pin icon remain unchanged.
- **Android:** target API 36; Flutter 3.50; stable applicationId `app.reachnetwork.reach_network`; protected upload signing key retained.
- **Build:** v1.0.5 release candidate must pass Flutter analysis, tests, both APK builds, live policy URL checks, signed AAB and **compiled manifest least-permissions audit**. Check latest GitHub Actions result before claiming build availability.
- **Privacy:** optional nearby sharing now declares only foreground coarse location by default. Dormant notification/audio/Bluetooth permissions are suppressed from the default bundle; no actual calling or push release claims.
- **Backend:** existing live Supabase project, RLS, member reports, safety inbox, public privacy and account-deletion portal; public publishable key matches Flutter config.
- **Operational gates not complete:** Play Console publisher account/verified legal identity, official support and child-safety contacts, production SMTP and callback settings, leaked-password blocking, human moderation/retention, physical-device two-account tests, real store screenshots, Console Data safety and App content declarations, applicable real closed testers and Play review.
- **No paid service has been authorized or enabled.** A successful AAB is not a Google Play listing.

See `docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md`.

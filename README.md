# Reach — Android Community Help

**Current release candidate: v1.0.5+6 (19 November 2026).**

Reach provides permission-based community assistance: time-limited offers/requests, city/country/optional approximate nearby discovery, invitation circles, searchable public groups, starter group templates, 23 topic categories, accepted connections and private chat. The default app also has report/block features, privacy controls, account deletion, and free rule-based on-device Reach Assist. Cloud AI, paid products, Google OAuth, background push, and voice/video calling are disabled by default until their separate release gates pass.

The private repository has a persistent upload signing workflow that builds universal APK, ARM64 APK and, with the four GitHub signing secrets, a signed **internal-test** Android App Bundle. Automated analysis and Flutter tests run in Actions. Successful compilation is not equivalent to Play approval or physical-device tests.

**Launch handoff:** [docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md](docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md).

**Public policies and account controls:** https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/index.html.

**Source of policies:** `supabase/functions/reach-legal/index.ts`; frontend snapshots in `docs/`. Backend migrations: `supabase/migrations/`.

**Security and no-cost guardrails:** Only the public Supabase publishable key is included in Flutter/browser code. Secrets are managed as GitHub Actions secrets or Supabase server-side environment variables. No paid service is enabled without approval. Real user moderation and Play Console contact identity remain operator tasks.

**Approved Reach brand identity:** The name remains **Reach**. The selected three-person community network inside a helping-hand location pin is versioned at `assets/branding/reach_selected_icon.webp`. The release pipeline renders all Android launcher density icons and Play 512×512 artwork from the same source; the in-app Reach mark uses this asset too.

**Play permission review:** v1.0.5 removes dormant Firebase notification/Bluetooth/audio and precise location permission entries from the merged Android manifest. Only approximate coarse location is requested for optional nearby discovery, and the AAB's actual manifest must pass `tools/check_android_bundle.py` before the signed artifact is uploaded. Calls and remote push remain disabled. This is a static manifest check and does not replace device QA.

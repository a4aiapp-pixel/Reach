# Reach — Android Community Help

**Current release candidate: v1.0.2+3 (18 November 2026).**

Reach provides permission-based community assistance: time-limited offers/requests, city/country/optional approximate nearby discovery, invitation circles, accepted connections and private chat. The default app also has report/block features, privacy controls, account deletion, and free rule-based on-device Reach Assist. Cloud AI, paid products, Google OAuth, background push, and voice/video calling are disabled by default until their separate release gates pass.

The private repository has a persistent upload signing workflow that builds universal APK, ARM64 APK and, with the four GitHub signing secrets, a signed **internal-test** Android App Bundle. Automated analysis and Flutter tests run in Actions. Successful compilation is not equivalent to Play approval or physical-device tests.

**Launch handoff:** [docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md](docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md).

**Public policies and account controls:** https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/index.html.

**Source of policies:** `supabase/functions/reach-legal/index.ts`; frontend snapshots in `docs/`. Backend migrations: `supabase/migrations/`.

**Security and no-cost guardrails:** Only the public Supabase publishable key is included in Flutter/browser code. Secrets are managed as GitHub Actions secrets or Supabase server-side environment variables. No paid service is enabled without approval. Real user moderation and Play Console contact identity remain operator tasks.

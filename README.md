# Reach — Android Community Help

**Current release candidate: v1.0.6+7 (19 November 2026).**

Reach provides permission-based community assistance: time-limited offers/requests, city/country/optional approximate nearby discovery, invitation circles, searchable public groups, starter group templates, 23 topic categories, accepted connections and private chat. The default app also has report/block features, privacy controls, account deletion, and free rule-based on-device Reach Assist. Cloud AI, paid products, Google OAuth, background push, and voice/video calling are disabled by default until their separate release gates pass.

The private repository has a persistent upload signing workflow that builds universal APK, ARM64 APK and, with the four GitHub signing secrets, a signed **internal-test** Android App Bundle. Automated analysis and Flutter tests run in Actions. Successful compilation is not equivalent to Play approval or physical-device tests.

**Launch handoff:** [docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md](docs/PLAY_CONSOLE_HANDOFF_2026_11_18.md).

**Public policies and account controls:** https://ffnhidnnqpamewcepxrr.supabase.co/functions/v1/reach-legal/index.html.

**Source of policies:** `supabase/functions/reach-legal/index.ts`; frontend snapshots in `docs/`. Backend migrations: `supabase/migrations/`.

**Security and no-cost guardrails:** Only the public Supabase publishable key is included in Flutter/browser code. Secrets are managed as GitHub Actions secrets or Supabase server-side environment variables. No paid service is enabled without approval. Real user moderation and Play Console contact identity remain operator tasks.

**Approved Reach brand identity:** The name remains **Reach**. The selected three-person community network inside a helping-hand location pin is versioned at `assets/branding/reach_selected_icon.webp`. The release pipeline renders all Android launcher density icons and Play 512×512 artwork from the same source; the in-app Reach mark uses this asset too.

**Play permission review:** v1.0.5 removes dormant Firebase notification/Bluetooth/audio and precise location permission entries from the merged Android manifest. Only approximate coarse location is requested for optional nearby discovery, and the AAB's actual manifest must pass `tools/check_android_bundle.py` before the signed artifact is uploaded. Calls and remote push remain disabled. This is a static manifest check and does not replace device QA.

**Place autocomplete:** Reach now includes offline autocomplete for countries and populated cities, filtered by the chosen country, generated from the open GeoNames dataset. No GPS access, commercial API key, network access or per-request fee is needed to type a place. For towns omitted from the curated dataset, users may enter the name manually. Prepare the assets with `python -m pip install geonamescache==3.0.2` followed by `python tools/generate_geo_assets.py` before `flutter pub get`. Attribution: GeoNames CC BY 4.0, via geonamescache MIT; see `docs/GEO_DATA_ATTRIBUTION.md`.

**Onboarding:** Once an adult member completes their account profile, Reach shows one consent-based permissions guide on first use. Approximate nearby location prompts only after choosing to enable it; camera/microphone/notifications remain disabled while those services are unavailable. Media and files are selected through Android's built-in file picker, not broad storage permission. Manual city/country entry and skipping location remain supported.

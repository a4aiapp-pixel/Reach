# Reach Assist: Offline-first, zero-provider-cost design

## Default functionality
Reach Assist's default mode uses `lib/reach_local_assist.dart` on the
device. It does **not** call the internet or an AI model, so it has no
provider-token, inference or server billing. This is a deterministic local
**smart-tools** engine (not generative AI). It offers:

- Guided help/offer post drafts with editable placeholders and no invented
  locations, identities, credentials or availability.
- Simple punctuation, spacing and abbreviation cleanup without changing
  facts or inventing claims. It is not a general grammar model.
- Pattern-based scam/privacy warning signs. No identity verification,
  fraud determination or safety guarantees.
- Contextual volunteering and community-project ideas, not live matches.
- Fixed English/Urdu everyday phrases, **not** arbitrary translation.
- Friendly navigation to these tools from discovery and user profile.

Local conversation state is held in memory during the screen session, not
saved to the backend. Responses are never sent to other Reach users or
posted automatically. Users must review before copying/sharing.

## Optional cloud functionality (disabled)
`AppConfig.aiEnabled` defaults to `false` in every normal build. It gates
a separate **opt-in cloud AI** switch. Even when a trusted operator enables
the switch with `--dart-define=ENABLE_REACH_AI=true`, each cloud message
requires explicit user consent to submit only the typed message and at
most six recent on-screen assistant messages to the provider.

`supabase/functions/reach-assist` validates verified sign-ins, user
suspensions, strict input size and server-side per-user/network/global
limits. It has no provider credential configured by this project and
returns unavailable without a backend model key. It uses `store:false`
for a supporting model API but provider-side data practices still require
a proper public disclosure and review before activation. Do not claim
end-to-end confidentiality with any cloud provider.

Do not add a paid AI API key, free-trial card, or paid model subscription
without explicit developer approval. No recurring charges or paid traffic
should be created as part of the free Play Store launch.

## Future genuinely AI-capable free option
An on-device language model could be supported *only* where a
device-supported, licensing-compliant runtime and downloadable model are
available. The current release does not include an LLM, and an on-device
model is not universally usable on older/low-memory Android devices.
Do not silently download large model weights or advertise unsupported
offline generative chat.

## Test and release requirements
- Full offline operation in airplane mode (local assistant only).
- Settings and prompt text clarity for AI vs deterministic tools.
- Check all text modes with Urdu/English input.
- Accessibility, text scaling, screen reader and clipboard safety.
- Verify no network calls or analytics transmit local prompts.
- Verify cloud feature is absent by default and backend rejects unconfigured
  provider requests without initiating paid inference.
- Re-review Play Data safety/AI-content policy before cloud activation.

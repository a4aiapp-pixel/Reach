# Reach v1.2.0 — Integrated community and design release (build 11)

## Release goal
Resolve the real-group onboarding dead end and make Reach a coherent social experience rather than disconnected feature pages. This is one coordinated QA candidate; no paid backend providers added and no Google Play production publication is implied.

## New application structure
Primary navigation on phones: **Explore · Chats · Calls · Groups · Me**, with a responsive sidebar on spacious tablets for Rail looks. The Explore page has a prominent Create Reach action and short quick-action carousel for offers, requests, people and groups. **My Reach** (previous primary tab) is accessible under **Me → My Reach and activity**, preserving the create/manage functions. Chats is direct access to private conversations, requests, and alerts; Calls lists mutually permitted people, offers direct voice/video actions, and shows recent call status. Groups opens the member workspace.

## Group journey
- **Groups → Create**: backend automatically generates a 10-character invite code. The new group workspace opens immediately following successful creation.
- **Groups → Join by code**: enter shared code; the member workspace opens after successful join.
- **Groups → Your groups → Open**: workspace with **Discussion**, **Reaches**, **Resources**, and **Members**. Your groups are now at the top of the Groups page, not buried underneath discovery and templates.
- **Invite members**: visible on public and private groups; share via Android share sheet, copy code, and owner-only rotate code (old code immediately invalid).
- **Discussion**: live member-only conversation (120 recent messages) with clear safety/report controls.
- **Reaches**: member-only offers and requests; publish a new group-scoped Reach using preselected group membership.
- **Resources**: curated notes and HTTPS references with secure upload-free, zero-cost model, rate limiting, remove and report. File/video uploads are intentionally not enabled.
- **Members**: member roster showing self, names and owner roles without exposing email, phone, DOB or private profile fields.

## Security and reliability
- New `reach_group_messages` and `reach_group_resources` tables use RLS membership read/insert, optional group-owner resource removal, server-side adult verification, rate limits and existing high-confidence text heuristics.
- `reach_group_posts` and `reach_group_members` RPCs enforce membership; private group resources are never publicly discoverable.
- Invitation codes are generated automatically on creation (a prior backend capability), not client-side cryptography. Owners may rotate them.
- `reach_my_call_history` exposes only records involving the signed-in person, excluding blocked peers.
- Reports now include member-only group messages and resources, with anti-spam limits and no self-reporting.
- New communication and workspace pages have retryable network handling and recover from blank states.

## Distinct design identities
Retain ten saved theme IDs (legacy selections remain valid) with deliberately different global compositions: Aurora Flow, Editorial Ink, Obsidian Pro, Coastal Glass, Terra Social, Neon Circuit, Alpine Focus, Sakura Bento, Blueprint Studio and Solstice Pop. Eight feed patterns (floating, editorial, compact, accent, bento, glass, timeline and dashboard); four header families in Discover and ten branded masthead variations on Chats, Calls, Groups and Me; varied navigation dock/underline/tile/sidebar/Material; theme-specific typography, density, surfaces and conversation bubbles. All content and controls remain usable across layouts.

## Testing and release
- Flutter analysis and unit/widget tests.
- Two distinct adult-eligible accounts should create/join a group, share code, rotate code, send/receive messages in realtime, create group-scoped Reach, post/view/remove resource, report inappropriate content, and leave/rejoin.
- Verify Calls, Chats, Groups and Me routes, notification navigation, profile toggles, and phone/tablet landscape usability.
- GitHub Actions should publish independently downloadable signed **v1.2.0** universal APK, ARM64 APK and Play internal-test AAB to private GitHub QA Release assets (Actions artifact storage is exhausted).
- Public Play publication depends on real-device validation, moderation operations and Play Console clearance. This update does not claim parity with top social applications absent user testing and performance benchmarking.

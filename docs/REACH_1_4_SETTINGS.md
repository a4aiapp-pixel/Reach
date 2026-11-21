# Reach v1.4.0 — streamlined Settings IA

This release reorganizes existing controls without changing member data,
server-side privacy rules, group content, or permission defaults.

- **Me**: identity card → Profile settings; My Reach & activity; Settings.
- **Settings**: one searchable, seven-category home (Profile; Appearance;
  Chats & media; Calls; Groups; Privacy & security; Help & account).
- **Profile**: view/edit identity, avatar, bio, specialties, optional
  professional profile; public/private visibility, discoverability and
  approximate-location consent.
- **Appearance**: System/Light/Dark and Design Studio with 10 existing layouts.
  Selection is immediate and saved by existing preference logic.
- **Chats & media**: mutual media consent, in-app activity alerts and separate
  mobile/Wi-Fi/roaming auto-download preferences.
- **Calls**: opt-in call permission and bandwidth, adaptive quality,
  auto-reconnect controls; foreground consent is unchanged.
- **Groups**: separate group invitation consent, direct-add consent and a
  clear link to owned/joined group management.
- **Privacy & security**: blocked members, policy and safety rules.
- **Help & account**: Reach Assist, support, sign out and guarded account
  deletion.

Privacy cards only render controls owned by their category; the original
all-controls widget remains compatible with existing regression tests.
Category privacy is freshly read from the server to avoid stale toggles
after moving between submenus. Parent routes retain Android back behavior,
without nested dialogs or a second independent settings store.

Before Google Play release, exercise all seven section routes, keyboard search,
theme modes, privacy save/rollback, group invitations and ownership actions,
call consent, cached downloads and account deletion in a two-device QA session.

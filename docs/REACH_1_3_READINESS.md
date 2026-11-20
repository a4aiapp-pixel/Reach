# Reach v1.3.0 · Pre-publication candidate

Integrated QA upgrade (build 12). Not a Google Play production approval.

- Group owners: add by account ID, username or exact email, or search people who opted into discovery/invitations. Direct addition requires the recipient's separate explicit permission; otherwise an invitation goes to their Groups inbox. Invite code sharing remains an independent action.
- Members: accept/decline pending invitations from the Groups tab; open shared workspaces; view group roster and opted-in photos.
- Profiles: public or private, configurable About/bio, interests and skills, optional locally compressed 512px JPEG avatar in a private Supabase bucket, optional color avatar, signed member-authorized photo reads, and profile viewing from People/Chats/Groups.
- Private chat: media opt-in required from both participants. Documents <=16 MiB, photos <=8 MiB, audio <=12 MiB, videos <=24 MiB, with per-user rolling daily and storage caps. No public group media. Attachment reports quarantine the item for moderation. No automated image/video safety classifier is provided.
- Data: per-network automatic download selections (mobile, Wi-Fi, roaming) for photos, audio, videos and documents. Data-saving defaults, conservative roaming check and manual access for large files. Android private temporary cache; no unnecessary broad storage permission.
- UX: cleaner onboarding and group wording, distinct visual designs, restrained haptics, theme transition animations, and animated completion feedback. Existing adult eligibility, privacy, reporting and blocking remain intact.

Free-tier storage limits prevent WhatsApp's 2 GB file-size parity. Actual limits are enforced in SQL and the app. These binaries require QA with two adult accounts, including blocked-peer access, media report quarantine, direct-add consent, avatar visibility, roaming and download settings before public release. Server-side content scanning and moderator workflows remain an outstanding public-launch risk.

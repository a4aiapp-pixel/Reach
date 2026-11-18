# Reach — Secure Audio / Video Calling Decision
Date: 18 November 2026
Status: ARCHITECTURE APPROVED, IMPLEMENTATION NOT ENABLED, NOT YET RELEASE-TESTED

## Product decision
Offer **free 1-to-1 voice and video calling** as an enhancement to a mutually
approved Reach conversation. Both people must explicitly consent to a call.
Do **not** turn this into anonymous/random calling or paid priority calling.
Do not delay the Play Store launch solely for unvalidated calling.

## User flow
1. A member opens an existing authorized conversation; no discovery user can cold-call them.
2. Caller taps Phone or Video, triggering a request without activating microphone/camera.
3. Callee sees identity, type, Decline / Accept, and can block/report caller.
4. Only after acceptance does device ask for audio/video permission and initialize media.
5. During call: mute, speaker route, camera on/off, camera flip, quality downgrade, and End.
6. On network loss: show reconnect state and offer voice-only; terminate and release
   media tracks automatically after bounded retries.
7. Missed-call notice appears only to authorized participants; do not expose phone numbers.

## Security / privacy requirements
- Verify both auth.uid() identities are the actual conversation participants.
- Verify connection has not been blocked, the app account is not suspended, and
  the caller is not rate-limited, in all signaling writes (not just in UI).
- Incoming offers expire (suggested 45 seconds); decline/busy are explicit.
- Throttle call attempts (suggested max 3 in 10 min per peer and 12 per hour total).
- Signaling events scoped to call UUID and participants; reject forwarded or
  stale offers/candidates. Do not put full SDP/ICE on public channels.
- TURN credentials must be short-lived and minted server-side; never hardcode
  provider API keys in Flutter sources.
- Provide end-call on block, sign-out, app termination and participant disconnect.
- Never auto-answer or silently grant microphone/camera permission.
- No default recordings, transcripts or biometric analysis; do not store media.
- Device-level WebRTC SRTP/DTLS encrypts media, including when TURN relays it.
- No phone-number disclosure; IP exposure remains a peer-to-peer WebRTC
  consideration and must be disclosed in the eventual privacy policy.
- Do not claim E2EE for messages, just media whose actual implementation has
  been independently confirmed.
- Do not offer calling to unverified/anonymous users; enforce age safeguards.

## Technical architecture
- Client media: Flutter `flutter_webrtc` pinned and security-audited before integration.
- Signaling: Supabase Realtime (private authorized conversation/call channel)
  with server-controlled short-lived call invitations and rate limits.
- NAT: peer-to-peer ICE with STUN where possible.
- Relay: dynamically issued TURN credentials for strict NAT/firewall cases;
  enforce provider spend caps, alerting and safe call fallbacks.
- Push: incoming calls should use existing opt-in FCM integration once live;
  without working push provide only foreground in-app calling, clearly labeled.
- Foreground/background Android: first launch may support foreground calls only.
  Background microphone/camera and full-screen call notifications require separate
  Android foreground-service/permission/policy validation.
- Call telemetry: duration and connection outcome only; no SDP, IPs or media
  stored in general application logs; aggregate and expire diagnostic metadata.
- No external payment provider is needed for free member calls.

## Revenue implications
Calling is a retention/engagement feature, not an ad placement.
Never show ads inside calls or hold call setup behind payment.
Pro/Business tiers may add legitimate non-essential scheduling and coordination
tools later, not basic calling or blocking/safety.
Video and TURN media egress may incur cost: an empty/monthly budget ceiling is
not a real cost control. Do not activate paid relay without explicit approval.

## Mandatory test matrix
- Two real Android devices, Wi-Fi <> cellular, different carriers, NAT/firewall
  requiring TURN, lost LTE during ringing, airplane mode mid-call.
- Low-memory, background, battery saver, orientation changes, headset/Bluetooth,
  speaker/mic permission denied, camera revoked during call.
- Simultaneous incoming calls, same person on two devices, race between
  accept/decline/timeout, retry/cancel, idle/sleep, crash and restart.
- User blocks caller while ringing or connected; all media/signaling must stop.
- Login not confirmed, session expired, unauthorized conversation ID, deleted user.
- Accessibility and font scaling, reduced animation, screen reader labels,
  visible in-call consent, visual/microphone operating system indicators.
- Verify cold startup, latency, packet loss and thermal/battery impact.
- Validate legal/privacy/Play Data safety declarations and content-moderation workflow.

## Release gate
DO NOT SHOW A FUNCTIONING CALL BUTTON OR ADVERTISE CALLING IN PLAY LISTING
until the above signaling, permissions, live calls and safety tests are verified.
Implement behind remote-config + build-time flag, default OFF.

References:
- https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Signaling_and_video_calling
- https://developers.cloudflare.com/realtime/turn/faq/
- https://support.google.com/googleplay/android-developer/answer/18265346

# Solana Dub Room — Requirements

**Status:** Side project  
**Priority:** High  
**Last updated:** 2026-06-24  
**Estimated build:** 3–4 weeks  
**Business model:** Freemium SaaS + sponsorship

---

## Overview

Solana Dub Room is a **live voice chat** where degens talk to each other — but everyone sounds like Solana CT legends (Ansem, Murad, Toly, etc.). Users speak normally; others hear them in a parody “legend” voice. Pure meme energy for Solana CT.

> **Core product:** a **live room** where users talk to each other in dubbed voices — **not** a solo dub generator.

**Stack (v1):** Next.js frontend · LiveKit (WebRTC) · [RVC](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) for legend voice skins · PocketBase backend · Coolify on Hetzner for hosting. ElevenLabs may be used interim while RVC models and real-time pipeline are wired up.

---

## Problem & Opportunity

Discord-style voice hangouts exist, but nothing lets a coin community show up and argue as Murad vs Toly in real time. Solana Dub Room fills that gap: meme-first, wallet-native, community-gated rooms for CT culture moments.

Legend voices are **parody RVC models** trained from public CT clips — self-hosted, not a paid voice API at scale. ElevenLabs stays in the stack only as a short-term fallback if RVC latency or quality isn’t ready for the Murad vs Toly demo.

---

## Goals

1. Ship a working **multi-user voice room** with real-time voice transformation.
2. Prove the concept with a **two-user demo** (e.g. Murad vs Toly debate).
3. Gate access via **Solana wallet** and optional **per-coin/community rooms**.
4. Launch with a **waitlist** and clear **parody disclaimer** everywhere.

---

## Non-Goals (v1)

- Solo dub tool / offline voice generator
- Full Discord replacement (text channels, bots, etc.)
- Licensed or official celebrity voices — all voices are clearly labeled parody
- Mobile-native apps (web-first is acceptable for v1)

---

## User Stories

| As a… | I want to… | So that… |
|-------|------------|----------|
| Degen | Join a live voice room | I can hang with other CT members |
| User | Pick a Solana OG voice skin | Others hear me as Ansem / Murad / Toly |
| Community member | Enter a wallet-gated room for my coin | Only holders or invited wallets can join |
| Organizer | Host a room for a launch or rug therapy session | The community has a shared meme space |
| Spectator | Listen without speaking (future) | I can enjoy debates via Coin Commentator-style listener mode |

---

## Core Features

### 1. Live voice rooms (must-have)

- Multi-user, real-time voice chat — **not** 1:1 or solo playback.
- User joins a room, selects a legend voice skin, speaks normally.
- All participants hear each other in their chosen parody voices with low enough latency for natural conversation.

### 2. Legend voice skins (must-have)

- Initial roster: Ansem, Murad, Toly (expandable).
- **Primary:** real-time voice conversion via [RVC](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) — train/load per-legend `.pth` models, run inference on GPU (Hetzner).
- **Interim fallback:** ElevenLabs real-time API if RVC pipeline isn’t ready for MVP demo.
- UI makes it obvious voices are **parody**, not the real person.

### 3. Auth — Privy + Solana wallet (must-have)

- Privy login (Solana external wallets; optional email).
- BFF verifies Privy JWT and syncs user to PocketBase.
- Wallet address used for room identity, LiveKit, and holder gating.

### 4. Wallet-gated rooms (must-have)

- Rooms scoped to a coin or community.
- Gate entry by wallet (holder checks, allowlists, or invite links — TBD per room type).

### 5. Parody disclaimer (must-have)

- Prominent disclaimer on join, in-room, and marketing: voices are parody; not affiliated with or endorsed by the real individuals.

### 6. Waitlist (must-have for launch)

- Landing page with waitlist signup before or alongside public beta.
- Capture wallet and/or email for early access.

### 7. LLM moderation (should-have)

- Automated moderation for harmful / illegal content in voice or associated chat.
- Escalation or mute/kick flows for room hosts (detail TBD).

### 8. Spectator / listener mode (nice-to-have)

- Pair with **Coin Commentator** or similar: non-speaking listeners who hear the room.
- Deferred if it blocks core room MVP.

---

## Use Cases

- **Coin community hangouts** — holders voice-chat as their favorite CT personalities.
- **Post-rug therapy rooms** — communal coping, meme energy.
- **Launch watch parties** — live reactions during token or product launches.
- **CT meme debates** — e.g. two users arguing as Murad vs Toly (flagship demo scenario).

---

## MVP Scope (launch checklist)

- [ ] Live multi-user voice room (WebRTC / LiveKit)
- [ ] Real-time voice dubbing (RVC; ElevenLabs acceptable interim)
- [ ] 3+ legend voice skins (Ansem, Murad, Toly)
- [ ] Solana wallet connect + room entry
- [ ] At least one wallet-gated community room
- [ ] Parody disclaimer on landing and in-room
- [ ] Waitlist landing page
- [ ] Demo: two users debating as Murad vs Toly
- [ ] Basic LLM moderation hook (even if rules are minimal at first)

---

## Technical Stack

| Layer | Choice |
|-------|--------|
| Frontend | Next.js |
| Real-time voice | WebRTC via LiveKit |
| Voice conversion (primary) | [RVC](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) — self-hosted, per-legend models |
| Voice conversion (interim) | ElevenLabs — until RVC real-time path is production-ready |
| Backend | PocketBase (auth helpers, rooms, waitlist, wallet records, moderation flags) |
| Auth | Privy (Solana wallet) → BFF → PocketBase session |
| Moderation | LLM-based pipeline |
| Hosting / infra | Coolify on Hetzner (app, PocketBase, RVC inference worker, LiveKit) |

---

## Demo Scenario

**Murad vs Toly argument**

1. User A joins Room “SOL Debate”, picks **Murad** voice.
2. User B joins same room, picks **Toly** voice.
3. Both speak normally; each hears the other in their chosen legend voice.
4. Observers (waitlist / future listener mode) can watch or hear the session.
5. Recording or clip export optional for marketing — not required for v1.

---

## Open Questions

- RVC integration: dedicated inference service vs sidecar per room? Target latency budget for live chat?
- ElevenLabs cutover: when to drop interim API once RVC models pass quality bar?
- Holder verification: on-chain token balance vs manual allowlist vs both?
- Room limits: max participants per room at launch?
- Freemium gates: free minutes, voice skin tiers, or sponsored rooms?
- Moderation liability: human review queue vs automated-only for v1?
- Coin Commentator integration: same repo, shared auth, or separate product?

---

## Success Metrics (v1)

- Waitlist signups
- Wallet connects
- Rooms created / joined
- Average session duration
- Demo video shares / social traction
- Sponsorship or paid room interest

---

## Legal & Brand

- All voices and personas are **parody**.
- No implication of endorsement by Ansem, Murad, Toly, or any real individual.
- Disclaimer visible before first join and persistent in UI.
- Review ToS / privacy policy for voice data and wallet addresses before public launch.

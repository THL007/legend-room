# Solana Dub Room — Design

**Related:** [REQUIREMENTS.md](./REQUIREMENTS.md)  
**Last updated:** 2026-06-24  
**Status:** Draft (MVP)

---

## 1. Design goals

| Goal | Approach |
|------|----------|
| Low-latency live voice | LiveKit for transport; RVC on GPU close to LiveKit |
| Meme-first UX | Voice skin picker before join; parody labels everywhere |
| Wallet-native access | Privy (Solana wallets) → BFF verifies token → PocketBase user; holder checks at room gate |
| Ship in 3–4 weeks | Monorepo-friendly layout; ElevenLabs only as interim voice path |
| Self-hosted cost control | PocketBase + Coolify on Hetzner; no per-minute voice API at scale |

---

## 2. High-level architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  Browser (Next.js)                                                      │
│  · Privy auth (Solana wallet + optional email)                          │
│  · Room UI, voice skin picker, disclaimer                               │
│  · LiveKit client SDK (mic in / dubbed audio out)                       │
└───────────────┬───────────────────────────────┬─────────────────────────┘
                │ HTTPS / WS                      │ WebRTC
                ▼                                 ▼
┌───────────────────────────┐         ┌───────────────────────────────────┐
│  PocketBase               │         │  LiveKit Server                   │
│  · Users, rooms, waitlist │         │  · SFU for multi-user voice rooms │
│  · Access rules, tokens   │         │  · Per-participant audio tracks   │
│  · Moderation events      │         └───────────────┬───────────────────┘
└───────────────┬───────────┘                         │
                │ issue LiveKit JWT                     │ audio streams
                ▼                                       ▼
┌───────────────────────────┐         ┌───────────────────────────────────┐
│  Next.js API routes       │         │  Voice pipeline worker            │
│  (BFF / edge helpers)     │◄───────►│  · Subscribe participant audio    │
│  · Privy JWT verify       │         │  · RVC inference (per skin)       │
│  · Holder check (RPC)     │         │  · Publish dubbed track back      │
│  · ElevenLabs fallback    │         │  (interim: ElevenLabs stream API) │
└───────────────────────────┘         └───────────────────────────────────┘
                                                │
                                                ▼
                                    ┌───────────────────────────────────┐
                                    │  Hetzner GPU (Coolify service)    │
                                    │  RVC models: ansem, murad, toly   │
                                    └───────────────────────────────────┘
```

**Principle:** PocketBase owns *who* can enter; LiveKit owns *real-time presence*; the voice worker owns *how participants sound*.

---

## 3. Core flows

### 3.1 Waitlist & landing

```text
User → / (landing) → optional email + wallet → POST /api/waitlist
                                              → PocketBase `waitlist` collection
```

No auth required. Wallet address stored if provided for early-access invites.

### 3.2 Auth (Privy + PocketBase)

#### Compatibility check

Privy and PocketBase **do not integrate natively**. PocketBase has no built-in Privy/OIDC provider. This is **compatible** via a **BFF bridge** (recommended for MVP):

| Approach | Compatible? | Notes |
|----------|-------------|-------|
| Privy client → BFF verifies access token → PocketBase writes | **Yes** | Recommended. Next.js verifies Privy JWT (JWKS), maps `user.id` + linked Solana wallet to `users` record; BFF uses PB admin token for server-side writes. |
| Privy token directly in PocketBase API rules | **No** | PB cannot verify Privy JWTs out of the box. |
| Custom PocketBase Go middleware | **Yes** | Verify Privy JWT in `OnBeforeServe` hook, set `ContextAuthRecordKey`. Heavier ops; defer unless BFF becomes a bottleneck. |

**Conclusion:** Use **Privy on the frontend** for login (Solana external wallets + optional email/social). Use **Next.js BFF** to verify Privy access tokens and sync identity into PocketBase. Holder gating still uses the **Solana wallet address** from Privy’s linked accounts.

```text
1. Client: Privy login (wallet-first: Phantom, Backpack, etc.; optional email)
2. Client: obtain Privy access token (JWT, ~1h TTL; SDK handles refresh)
3. Client: POST /api/auth/sync { Authorization: Bearer <privy_access_token> }
4. BFF: verify JWT signature against Privy app JWKS (issuer, exp, aud)
5. BFF: extract privy_user_id + linked Solana wallet(s) from token / Privy API
6. BFF: upsert PocketBase `users` (privy_id, wallet, email if present)
7. BFF: set httpOnly session cookie (opaque id → PB user) OR return short-lived BFF session JWT
8. Subsequent API calls: session cookie or Bearer; BFF resolves PocketBase user
```

Wallet remains the **room identity** (LiveKit `sub`, holder checks). Privy `user.id` is the stable auth key across devices. Email from Privy can pre-fill waitlist / notifications.

### 3.3 Join room

```text
1. User picks room (public or wallet-gated)
2. BFF checks gate:
   · open room → allow
   · holder room → Solana RPC token balance ≥ threshold OR allowlist match
   · invite room → valid invite token
3. User accepts parody disclaimer (stored on `room_sessions` or client + server flag)
4. User selects voice skin (ansem | murad | toly)
5. BFF mints LiveKit token (room name, identity=wallet, metadata: skin_id)
6. Client connects LiveKit; voice worker assigned skin from token metadata
7. User mic → worker → dubbed audio → other participants
```

### 3.4 Voice path (RVC — target)

```text
Mic (browser)
  → LiveKit publish (raw track, muted to others OR worker-only subscription)
  → Voice worker subscribes to participant track
  → Chunk audio (20–40 ms frames, 48 kHz)
  → RVC infer(skin_model, pcm) → dubbed pcm
  → Worker publishes dubbed track as participant's "voice" track
  → SFU fans out to room
```

**Latency budget (target):** ≤ 250 ms mouth-to-ear (stretch ≤ 350 ms for MVP demo).

| Stage | Target |
|-------|--------|
| WebRTC capture + encode | 40–80 ms |
| LiveKit SFU hop | 20–40 ms |
| RVC inference | 90–170 ms |
| Decode + playout | 40–60 ms |

### 3.5 Voice path (ElevenLabs — interim)

Same LiveKit shell; worker forwards PCM to ElevenLabs real-time voice API with a preconfigured parody voice id per skin. Swap worker backend when RVC quality/latency passes acceptance tests.

---

## 4. Services & responsibilities

| Service | Runtime | Responsibility |
|---------|---------|----------------|
| **web** | Next.js on Coolify | UI, BFF routes, Privy JWT verify, LiveKit token mint |
| **pocketbase** | Coolify | DB, collections, hooks, admin UI |
| **livekit** | Coolify (or LiveKit Cloud for MVP speed) | WebRTC SFU, room lifecycle |
| **voice-worker** | Coolify on GPU box | RVC / ElevenLabs; track subscribe → dub → republish |
| **moderation-worker** | Coolify (CPU) | Optional async: transcript snippets → LLM → flag/kick |

---

## 5. PocketBase data model

### 5.1 Collections

#### `users`

| Field | Type | Notes |
|-------|------|-------|
| `privy_id` | text (unique) | Privy `user.id` |
| `wallet` | text (unique) | Primary Solana pubkey, base58 |
| `email` | email | From Privy if linked |
| `display_name` | text | Optional; default truncated wallet |
| `avatar_url` | url | Optional |
| `disclaimer_accepted_at` | datetime | Global parody ack |
| `role` | select | `user` \| `host` \| `admin` |

#### `waitlist`

| Field | Type | Notes |
|-------|------|-------|
| `email` | email | Optional |
| `wallet` | text | Optional |
| `source` | text | utm / referral |
| `invited` | bool | Early access sent |

#### `voice_skins`

| Field | Type | Notes |
|-------|------|-------|
| `slug` | text (unique) | `ansem`, `murad`, `toly` |
| `label` | text | Display name + “(Parody)” |
| `rvc_model_path` | text | Path on GPU volume |
| `elevenlabs_voice_id` | text | Interim only |
| `preview_url` | url | Short sample clip |
| `enabled` | bool | Feature flag per skin |

#### `rooms`

| Field | Type | Notes |
|-------|------|-------|
| `slug` | text (unique) | URL segment |
| `name` | text | e.g. “SOL Debate” |
| `host` | relation → `users` | Creator |
| `gate_type` | select | `open` \| `holder` \| `allowlist` \| `invite` |
| `mint_address` | text | SPL token for holder gate |
| `min_balance` | number | Holder threshold |
| `max_participants` | number | Default 10 MVP |
| `livekit_room` | text | LiveKit room id (often = slug) |
| `status` | select | `scheduled` \| `live` \| `ended` |
| `sponsor_label` | text | Optional freemium / sponsorship |

#### `room_allowlist`

| Field | Type | Notes |
|-------|------|-------|
| `room` | relation → `rooms` | |
| `wallet` | text | Allowed pubkey |

#### `room_sessions`

| Field | Type | Notes |
|-------|------|-------|
| `room` | relation → `rooms` | |
| `user` | relation → `users` | |
| `voice_skin` | relation → `voice_skins` | Chosen at join |
| `joined_at` | datetime | |
| `left_at` | datetime | |
| `disclaimer_accepted` | bool | Per-session ack |

#### `moderation_events`

| Field | Type | Notes |
|-------|------|-------|
| `room` | relation → `rooms` | |
| `user` | relation → `users` | |
| `type` | select | `flag` \| `mute` \| `kick` |
| `reason` | text | LLM or host |
| `created_at` | datetime | |

### 5.2 Access rules (sketch)

- `rooms`: public read for listing; create requires auth; update host or admin only.
- `room_sessions`: user can read own; insert on successful join via BFF.
- `waitlist`: create open; read admin only.

Sensitive ops (LiveKit token, holder verify) go through **Next.js BFF**, not direct client PocketBase rules.

---

## 6. API surface (BFF)

Base path: `/api`

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/auth/sync` | Privy JWT | Verify Privy token → PB user upsert → session |
| GET | `/auth/me` | session | Current user + linked wallet |
| POST | `/auth/logout` | session | Clear session |
| POST | `/waitlist` | — | Add waitlist entry |
| GET | `/rooms` | optional | List public / live rooms |
| GET | `/rooms/:slug` | optional | Room detail + gate hint |
| POST | `/rooms/:slug/join` | wallet | Gate check, disclaimer, return LiveKit token + skin |
| POST | `/rooms` | wallet | Create room (host) |
| GET | `/voice-skins` | — | Enabled skins + previews |
| POST | `/moderation/flag` | wallet | Host/admin flag user (MVP hook) |

### LiveKit token claims (example)

```json
{
  "sub": "wallet_pubkey",
  "room": "sol-debate",
  "metadata": {
    "skin": "murad",
    "display_name": "7xK9...ab",
    "can_publish": true
  }
}
```

Voice worker reads `metadata.skin` on participant connect.

---

## 7. Voice worker design

### 7.1 Process model (MVP)

One **voice-worker** deployment per GPU host:

- Connects to LiveKit as a specialized participant (or uses LiveKit server SDK / egress patterns).
- Maintains a map: `participant_id → { skin, rvc_session, buffer }`.
- On track subscribed: spawn async inference loop.
- On skin change: drain buffer, reload model context (or queue switch).

Start with **one shared worker** for all rooms; scale to per-room workers only if CPU/GPU contention appears.

### 7.2 RVC integration

- Base image: Python + CUDA, RVC inference code from [RVC WebUI](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) (inference-only subset or sidecar API).
- Models stored on Hetzner volume: `/models/{slug}.pth` + index files.
- HTTP/gRPC internal API (optional):

```text
POST /infer
{ "skin": "murad", "pcm_base64": "...", "sample_rate": 48000 }
→ { "pcm_base64": "..." }
```

Prefer **streaming websocket** for lower overhead once MVP works.

### 7.3 ElevenLabs interim

Environment flag: `VOICE_BACKEND=elevenlabs|rvc`

Worker branches on flag; same outward LiveKit interface. Acceptance criteria to cut over:

- Murad vs Toly demo intelligible at conversational pace
- p95 latency ≤ 250 ms on Hetzner GPU
- No critical artifacts on 10 min continuous speech

---

## 8. Frontend design

### 8.1 Routes

| Route | Purpose |
|-------|---------|
| `/` | Landing, parody disclaimer, waitlist CTA |
| `/rooms` | Browse live / upcoming rooms |
| `/rooms/[slug]` | Pre-join: gate status, skin picker, join button |
| `/rooms/[slug]/live` | In-room UI (participants, mute, leave, disclaimer banner) |
| `/admin` | PocketBase admin or thin host dashboard (post-MVP) |

### 8.2 Key UI states

1. **Disconnected** — Privy login (wallet-first)
2. **Lobby** — pick skin, read disclaimer, join
3. **Connecting** — LiveKit + worker handshake
4. **Live** — participant grid, speaking indicators, skin badge per user
5. **Kicked / ended** — room closed message

### 8.3 Visual design system

**Tone:** serious product shell (readable, trustworthy, AA-accessible) with **meme accents** on voice skins, room titles, and CT copy — not chaotic everywhere.

#### Shape — rounded edges

All interactive surfaces use consistent radius tokens (Tailwind):

| Token | Value | Use |
|-------|-------|-----|
| `radius-sm` | `8px` | Chips, tags, small inputs |
| `radius-md` | `12px` | Buttons, inputs, tooltips |
| `radius-lg` | `16px` | Cards, modals, participant tiles |
| `radius-xl` | `24px` | Hero panels, bottom sheets |
| `radius-full` | `9999px` | Pills, avatars, mic button |

No sharp 0-radius corners on UI components. In-room mic control is a large circular (`radius-full`) primary button.

#### Color — high contrast (WCAG AA)

Target **≥ 4.5:1** contrast for body text, **≥ 3:1** for large headings and UI components. Validate with contrast checker before ship.

**Dark theme (default)** — fits CT / late-night voice chat:

| Token | Hex | Role | Pairing |
|-------|-----|------|---------|
| `bg-base` | `#08080C` | Page background | — |
| `bg-surface` | `#12121A` | Cards, panels | text-primary |
| `bg-elevated` | `#1C1C28` | Modals, bottom sheets | text-primary |
| `text-primary` | `#F4F4F8` | Body copy | on bg-surface → **~15:1** |
| `text-secondary` | `#A8A8B8` | Meta, captions | on bg-surface → **~7:1** |
| `accent-primary` | `#7C3AED` | Primary buttons, links | white text → **~4.6:1** |
| `accent-sol` | `#14F195` | Solana highlight, live badge | `#08080C` text → **~12:1** |
| `warning` | `#FBBF24` | Parody disclaimer banner | `#12121A` text → **~10:1** |
| `danger` | `#F87171` | Leave, kick, errors | on bg-surface |
| `border` | `#2A2A3A` | Dividers | — |

**Light theme (optional, post-MVP):** invert surfaces; keep `accent-primary` and `accent-sol` but test contrast on white (`#FFFFFF`) before enabling.

**Rules:**
- Never place `text-secondary` on `bg-base` for critical actions — use `text-primary`.
- Parody disclaimer uses `warning` bg + dark text, always visible in-room.
- Focus rings: `2px solid #14F195` offset — keyboard nav AA.

#### Typography — serious + meme pairing

Two-font stack via `next/font`:

| Role | Font | Weight | Usage |
|------|------|--------|-------|
| **UI / body (serious)** | [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3) | 400, 600 | Paragraphs, labels, legal, disclaimer body, form fields |
| **Display (serious)** | [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) | 600, 700 | Page titles, section headers, room names in lists |
| **Meme accent** | [Bungee](https://fonts.google.com/specimen/Bungee) | 400 | Voice skin names (“MURAD”), live badges, easter-egg headings only |

**Rules:**
- Body never uses Bungee — meme font is for **short strings** (≤ 3 words).
- Minimum body size **16px** on mobile (prevents iOS zoom + aids AA).
- Line-height ≥ 1.5 for body; headings ≥ 1.2.
- All caps only for meme labels, not legal copy.

```text
Landing H1:     Space Grotesk 700
Skin card tag:  Bungee 400, uppercase, accent-sol
Disclaimer:     Source Sans 3 400, 16px
Button label:   Source Sans 3 600
```

### 8.4 Responsive layout — mobile + desktop

**Mobile-first.** Single codebase; layout adapts at breakpoints:

| Breakpoint | Width | Layout |
|------------|-------|--------|
| `sm` | ≥ 640px | Single column; larger tap targets |
| `md` | ≥ 768px | Two-column lobby (skin grid + room info) |
| `lg` | ≥ 1024px | Desktop: sidebar + main stage |
| `xl` | ≥ 1280px | Wider participant grid, max-width container `1280px` |

#### Mobile (primary for degens on phone)

- **Landing:** stacked hero, full-width waitlist CTA, sticky bottom “Connect wallet” bar.
- **Skin picker:** horizontal scroll cards **or** bottom sheet (`radius-xl` top corners).
- **Live room:**
  - Compact participant strip (horizontal scroll avatars).
  - **Sticky bottom bar:** mute · deafen · leave (min 48×48px touch targets).
  - Parody disclaimer: collapsible chip, expanded by default on first join.
- **Safe areas:** `env(safe-area-inset-*)` for notched devices.
- **Mic permission:** priming screen before browser prompt (reduces drop-off).

#### Desktop

- **Landing:** split hero (copy left, demo video / illustration right).
- **Lobby:** skin grid 3 columns; room metadata in right rail.
- **Live room:**
  - Left sidebar: participant list with skin badge + speaking glow.
  - Center: “stage” area (optional visualizer / room title).
  - Bottom center: floating pill control bar (`radius-full`).
- Hover states on cards; no hover-only critical actions (mobile parity).

#### Shared

- `viewport` meta + responsive `next/image` assets.
- Test on iOS Safari + Chrome Android (WebRTC + Privy wallet deep links).
- Reduce motion: respect `prefers-reduced-motion` (disable speaking pulse animation).

### 8.5 In-room UI (MVP)

- Persistent **parody banner**: “Parody voices — not affiliated with or endorsed by any real person.” (`warning` token, `radius-md`)
- Participant tile: wallet short id + skin avatar (`radius-lg` card)
- Skin label in Bungee on tile; wallet id in Source Sans 3
- Controls: mute, deafen, change skin (rejoin track), leave
- Max 10 participants (configurable per room)

### 8.6 Tech choices

- Next.js App Router
- `@privy-io/react-auth` + `@privy-io/react-auth/solana` (wallet login, Solana address)
- `livekit-client` + `@livekit/components-react`
- Tailwind CSS + design tokens above (`tailwind.config` theme extend)
- `next/font` for Source Sans 3, Space Grotesk, Bungee

---

## 9. Wallet gating

### 9.1 Holder check

```text
BFF → Solana JSON-RPC (Helius / public)
  getTokenAccountsByOwner(wallet, { mint })
  → sum UI amount ≥ rooms.min_balance
```

Cache result 60s per wallet+mint to reduce RPC load.

### 9.2 Gate types

| Type | Check |
|------|-------|
| `open` | Wallet auth only |
| `holder` | Token balance ≥ threshold |
| `allowlist` | Wallet in `room_allowlist` |
| `invite` | Signed invite JWT or one-time code |

---

## 10. Moderation (MVP hook)

Async, non-blocking for v1:

1. Voice worker optionally emits short transcript chunks (future: streaming STT).
2. Moderation worker sends text to LLM with policy prompt.
3. On violation: write `moderation_events`, call LiveKit server API to mute/remove participant.

MVP may ship with **host manual kick only** + schema in place for automated flags.

---

## 11. Deployment (Coolify on Hetzner)

### 11.1 Topology

| Coolify service | Machine | Notes |
|-----------------|---------|-------|
| `legend-room-web` | CX/CPX | Next.js, env secrets |
| `legend-room-pocketbase` | same or dedicated | SQLite or Postgres plugin |
| `legend-room-livekit` | CPX | UDP ports for WebRTC |
| `legend-room-voice-worker` | **GPU** (GEX44 or similar) | RVC + CUDA |
| Reverse proxy | Coolify traefik | TLS, `app.`, `api.`, `livekit.` |

### 11.2 Environment variables (core)

```bash
# Web
NEXT_PUBLIC_LIVEKIT_URL=wss://livekit.example.com
NEXT_PUBLIC_POCKETBASE_URL=https://api.example.com
NEXT_PUBLIC_PRIVY_APP_ID=
PRIVY_APP_SECRET=
SOLANA_RPC_URL=
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
SESSION_SECRET=

# Voice worker
VOICE_BACKEND=rvc          # or elevenlabs
RVC_MODELS_DIR=/models
ELEVENLABS_API_KEY=        # interim only
LIVEKIT_URL=
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
```

### 11.3 Volumes

- `pocketbase_data` — PB database & uploads
- `rvc_models` — `.pth` + index files (read-only mount on worker)

---

## 12. Security

- LiveKit tokens: short TTL (e.g. 1h), room-scoped, minted server-side only.
- Privy access tokens: verified server-side via JWKS; never trust client-decoded claims alone.
- BFF session: httpOnly, Secure, SameSite=Lax cookie.
- No private keys on client; holder checks server-side only.
- Parody disclaimer: required before first `room_sessions` insert.
- Rate limit: join, waitlist, auth endpoints (Coolify proxy or BFF middleware).
- Voice data: not persisted in v1 unless explicit clip export (off by default).

---

## 13. MVP phases

### Phase 1 — Skeleton (week 1)

- Next.js landing + waitlist → PocketBase
- Privy auth + BFF → PocketBase user sync
- PocketBase collections + seed voice skins
- LiveKit room: raw voice only (no dub) to validate WebRTC

### Phase 2 — Voice (week 2)

- Voice worker with ElevenLabs OR first RVC skin
- Skin picker + dubbed track publish
- Two-user Murad vs Toly demo path

### Phase 3 — Gates & polish (week 3)

- Holder-gated room
- Parody disclaimer UX + AA contrast pass
- Mobile live-room bottom bar + desktop sidebar layout
- Participant list, mute, leave
- Deploy all services on Coolify / Hetzner

### Phase 4 — Hardening (week 4)

- RVC cutover (if on ElevenLabs interim)
- Basic moderation hook
- Metrics: join count, session duration, latency p95
- Demo video / waitlist invite batch

---

## 14. Observability

| Signal | Tool |
|--------|------|
| LiveKit room count | LiveKit metrics / logs |
| Voice latency | Worker histogram (infer ms) |
| Join failures | BFF structured logs (gate reason) |
| GPU util | Node exporter on GPU box |
| Errors | Coolify log drains |

---

## 15. Freemium / sponsorship (design hooks)

Not required for MVP runtime, but schema supports:

- `rooms.sponsor_label` — branded room
- Future `plans` collection: free minutes, premium skins
- Listener-only role in LiveKit token (`can_publish: false`) for Coin Commentator integration

---

## 16. Open design decisions

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Raw vs dubbed track | Publish raw muted + dubbed public | Dubbed only to others; optional monitor of raw for self |
| LiveKit hosting | Self-host vs Cloud | Self-host on Hetzner if UDP/TURN straightforward; else Cloud for week-1 |
| RVC worker API | In-process vs sidecar HTTP | Sidecar HTTP first for simpler deploy |
| PocketBase auth | Custom JWT vs PB auth collection | **Decided:** Privy JWT verified in BFF → httpOnly session + PB service role for writes |
| STT for moderation | Deepgram / Whisper / defer | Defer automated STT; host kick only in MVP |

---

## 17. Demo acceptance criteria

**Murad vs Toly debate** is done when:

1. Two browsers, two wallets, same room slug.
2. Each selects different skin; both hear the other in parody voice.
3. Parody disclaimer shown before audio.
4. Session stable ≥ 5 minutes without drop.
5. Screen recording captured for marketing waitlist.

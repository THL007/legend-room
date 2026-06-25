#!/usr/bin/env bash
# Creates GitHub issues for Solana Dub Room MVP. Idempotent: skips if title exists.
set -euo pipefail
REPO="THL007/legend-room"

create_label() {
  gh label create "$1" --color "$2" --description "$3" --repo "$REPO" 2>/dev/null || true
}

issue_exists() {
  gh issue list --repo "$REPO" --search "in:title \"$1\"" --json title --jq 'length' | grep -qv '^0$'
}

create_issue() {
  local title="$1"
  local labels="$2"
  local body="$3"
  if issue_exists "$title"; then
    echo "SKIP (exists): $title"
    return 0
  fi
  gh issue create --repo "$REPO" --title "$title" --label "$labels" --body "$body"
  echo "CREATED: $title"
}

# Labels
create_label "phase-1" "0E8A16" "Week 1 — skeleton"
create_label "phase-2" "1D76DB" "Week 2 — voice pipeline"
create_label "phase-3" "FBCA04" "Week 3 — gates and polish"
create_label "phase-4" "D93F0B" "Week 4 — hardening"
create_label "frontend" "7057FF" "Next.js UI"
create_label "backend" "006B75" "PocketBase and BFF"
create_label "auth" "B60205" "Privy and sessions"
create_label "voice" "5319E7" "LiveKit RVC ElevenLabs"
create_label "infra" "333333" "Coolify Hetzner deploy"
create_label "design" "E99695" "Visual system and UX"
create_label "legal" "FEF2C0" "Disclaimer ToS privacy"

# ─── Phase 1: Skeleton ───────────────────────────────────────────────────────

create_issue "Scaffold Next.js app with App Router and monorepo layout" "phase-1,frontend" "$(cat <<'EOF'
## Summary
Initialize the `web` Next.js application (App Router) as the foundation for landing, lobby, and live room UIs.

## References
- `docs/DESIGN.md` §4, §8.1, §8.6
- `docs/REQUIREMENTS.md` Technical Stack

## Tasks
- [ ] Create `apps/web` (or root `web/`) with Next.js 14+ App Router
- [ ] TypeScript strict mode
- [ ] ESLint + Prettier aligned with repo conventions
- [ ] Env var schema (`.env.example`) for Privy, PocketBase, LiveKit, Solana RPC
- [ ] Health check route `/api/health`

## Acceptance criteria
- `npm run dev` starts without errors
- README documents local dev setup
EOF
)"

create_issue "Configure Tailwind design tokens (colors, radius, contrast)" "phase-1,frontend,design" "$(cat <<'EOF'
## Summary
Implement the dark-theme design system with rounded edges and WCAG AA contrast tokens.

## References
- `docs/DESIGN.md` §8.3 (Shape, Color)

## Tasks
- [ ] Extend `tailwind.config` with tokens: `bg-base`, `bg-surface`, `bg-elevated`, `text-primary`, `text-secondary`, `accent-primary`, `accent-sol`, `warning`, `danger`, `border`
- [ ] Radius tokens: `sm` 8px, `md` 12px, `lg` 16px, `xl` 24px, `full`
- [ ] Focus ring utility: `2px solid #14F195` with offset
- [ ] Document contrast pairs in code comments

## Acceptance criteria
- All semantic colors available as Tailwind classes
- No UI component uses `rounded-none` by default
- Contrast checker documents ≥4.5:1 for body text on `bg-surface`
EOF
)"

create_issue "Load typography: Source Sans 3, Space Grotesk, Bungee via next/font" "phase-1,frontend,design" "$(cat <<'EOF'
## Summary
Set up the serious/meme font pairing per design spec.

## References
- `docs/DESIGN.md` §8.3 Typography

## Tasks
- [ ] `next/font/google` for Source Sans 3 (400, 600), Space Grotesk (600, 700), Bungee (400)
- [ ] CSS variables: `--font-body`, `--font-display`, `--font-meme`
- [ ] Tailwind `fontFamily` mapping
- [ ] Base body: 16px min on mobile, line-height 1.5

## Acceptance criteria
- Bungee used only via `font-meme` utility (documented in Storybook or README)
- Headings use Space Grotesk; body uses Source Sans 3
EOF
)"

create_issue "Build shared UI primitives (Button, Card, Chip, BottomSheet)" "phase-1,frontend,design" "$(cat <<'EOF'
## Summary
Reusable components enforcing rounded edges, AA contrast, and touch targets.

## References
- `docs/DESIGN.md` §8.3, §8.4

## Tasks
- [ ] `Button` — primary/secondary/danger, `radius-md`, min-height 44px mobile
- [ ] `Card` — `radius-lg`, `bg-surface`, border token
- [ ] `Chip` — `radius-sm`, live badge variant with `accent-sol`
- [ ] `BottomSheet` — `radius-xl` top corners, safe-area padding
- [ ] `DisclaimerBanner` — `warning` bg, Source Sans 3 16px

## Acceptance criteria
- Components work on mobile and desktop
- Keyboard focus visible on all interactive elements
EOF
)"

create_issue "Deploy PocketBase on Coolify (Hetzner)" "phase-1,backend,infra" "$(cat <<'EOF'
## Summary
Run PocketBase as a Coolify service with persistent volume.

## References
- `docs/DESIGN.md` §4, §11.1, §11.3
- `docs/REQUIREMENTS.md` Technical Stack

## Tasks
- [ ] Coolify service `legend-room-pocketbase`
- [ ] Volume `pocketbase_data` mounted
- [ ] TLS via Traefik (`api.` subdomain)
- [ ] Admin account created; credentials in secrets store
- [ ] Backup strategy documented (SQLite snapshot)

## Acceptance criteria
- PocketBase admin UI reachable over HTTPS
- Health endpoint responds
EOF
)"

create_issue "Create PocketBase users collection" "phase-1,backend" "$(cat <<'EOF'
## Summary
Define `users` collection per data model.

## References
- `docs/DESIGN.md` §5.1 `users`

## Tasks
- [ ] Fields: `privy_id` (unique), `wallet` (unique), `email`, `display_name`, `avatar_url`, `disclaimer_accepted_at`, `role` (user|host|admin)
- [ ] Indexes on `privy_id`, `wallet`
- [ ] Migration/export script or PB collection JSON in repo

## Acceptance criteria
- Admin can create test user manually
- Unique constraints enforced
EOF
)"

create_issue "Create PocketBase waitlist collection" "phase-1,backend" "$(cat <<'EOF'
## Summary
Store waitlist signups for launch.

## References
- `docs/DESIGN.md` §5.1 `waitlist`, §3.1
- `docs/REQUIREMENTS.md` §6 Waitlist

## Tasks
- [ ] Fields: `email`, `wallet`, `source`, `invited` (bool)
- [ ] API rule: create open; read admin only

## Acceptance criteria
- Record creatable via API with email and/or wallet
EOF
)"

create_issue "Create PocketBase voice_skins collection and seed Ansem Murad Toly" "phase-1,backend" "$(cat <<'EOF'
## Summary
Voice skin registry with seed data for MVP roster.

## References
- `docs/DESIGN.md` §5.1 `voice_skins`
- `docs/REQUIREMENTS.md` §2 Legend voice skins

## Tasks
- [ ] Fields: `slug`, `label` (with Parody suffix), `rvc_model_path`, `elevenlabs_voice_id`, `preview_url`, `enabled`
- [ ] Seed: `ansem`, `murad`, `toly` with `enabled: true`
- [ ] Public read rule for listing

## Acceptance criteria
- Three skins queryable via API
- Labels include parody indication
EOF
)"

create_issue "Create PocketBase rooms and room_allowlist collections" "phase-1,backend" "$(cat <<'EOF'
## Summary
Room metadata and allowlist for wallet-gated access.

## References
- `docs/DESIGN.md` §5.1 `rooms`, `room_allowlist`

## Tasks
- [ ] `rooms`: slug, name, host (relation), gate_type, mint_address, min_balance, max_participants (default 10), livekit_room, status, sponsor_label
- [ ] `room_allowlist`: room relation, wallet
- [ ] Public read for room listing; create requires auth via BFF

## Acceptance criteria
- Seed room `sol-debate` (open gate) for demo
- Holder-gated test room schema ready
EOF
)"

create_issue "Create PocketBase room_sessions and moderation_events collections" "phase-1,backend" "$(cat <<'EOF'
## Summary
Session tracking and moderation audit log.

## References
- `docs/DESIGN.md` §5.1 `room_sessions`, `moderation_events`, §10

## Tasks
- [ ] `room_sessions`: room, user, voice_skin, joined_at, left_at, disclaimer_accepted
- [ ] `moderation_events`: room, user, type (flag|mute|kick), reason, created_at
- [ ] Insert `room_sessions` via BFF only

## Acceptance criteria
- Join flow can persist session with disclaimer flag
EOF
)"

create_issue "Configure Privy app (Solana wallet-first)" "phase-1,auth,infra" "$(cat <<'EOF'
## Summary
Set up Privy dashboard for Solana Dub Room.

## References
- `docs/DESIGN.md` §3.2

## Tasks
- [ ] Create Privy app; note `NEXT_PUBLIC_PRIVY_APP_ID` and `PRIVY_APP_SECRET`
- [ ] Enable Solana external wallets (Phantom, Backpack, etc.)
- [ ] Optional: email login for waitlist continuity
- [ ] `walletChainType: solana-only` in client config
- [ ] Allowed domains for production + localhost

## Acceptance criteria
- Test wallet connect works in Privy preview
- JWKS endpoint documented for BFF verification
EOF
)"

create_issue "Integrate PrivyProvider in Next.js (Solana)" "phase-1,auth,frontend" "$(cat <<'EOF'
## Summary
Wrap app with Privy React SDK v3 + Solana peer deps.

## References
- `docs/DESIGN.md` §3.2, §8.6

## Tasks
- [ ] Install `@privy-io/react-auth`, Solana peer deps (`@solana/kit`, etc.)
- [ ] `PrivyProvider` client component with Solana RPC config
- [ ] `showWalletLoginFirst: true`
- [ ] Webpack externals in `next.config` if needed
- [ ] Login button component using `usePrivy` / `useWallets`

## Acceptance criteria
- User can connect Solana wallet on landing page
- `ready` state handled (loading UI)
EOF
)"

create_issue "Implement BFF POST /api/auth/sync (Privy JWT → PocketBase user)" "phase-1,auth,backend" "$(cat <<'EOF'
## Summary
Verify Privy access token and upsert PocketBase user.

## References
- `docs/DESIGN.md` §3.2, §6

## Tasks
- [ ] Verify JWT against Privy JWKS (iss, exp, aud)
- [ ] Extract `privy_id` + linked Solana wallet from token/Privy API
- [ ] Upsert `users` via PocketBase admin/service token
- [ ] Set httpOnly session cookie (`Secure`, `SameSite=Lax`)
- [ ] Rate limit endpoint

## Acceptance criteria
- Valid Privy token creates/updates PB user
- Invalid token returns 401
- Session cookie set on success
EOF
)"

create_issue "Implement BFF GET /api/auth/me and POST /api/auth/logout" "phase-1,auth,backend" "$(cat <<'EOF'
## Summary
Session read and destroy endpoints.

## References
- `docs/DESIGN.md` §6

## Tasks
- [ ] `GET /api/auth/me` — return user, wallet, disclaimer_accepted_at
- [ ] `POST /api/auth/logout` — clear session cookie
- [ ] Middleware helper `requireSession()` for protected routes

## Acceptance criteria
- Authenticated client receives user profile
- Logout clears cookie; subsequent `/me` returns 401
EOF
)"

create_issue "Implement POST /api/waitlist" "phase-1,backend,frontend" "$(cat <<'EOF'
## Summary
Waitlist signup API backing landing page.

## References
- `docs/DESIGN.md` §3.1, §6
- `docs/REQUIREMENTS.md` §6 Waitlist

## Tasks
- [ ] `POST /api/waitlist` — email and/or wallet, optional `source` (utm)
- [ ] Validate input; dedupe by email or wallet
- [ ] Write to PocketBase `waitlist`
- [ ] Rate limit (IP + wallet)

## Acceptance criteria
- Anonymous user can join waitlist
- Duplicate submissions handled gracefully
EOF
)"

create_issue "Build landing page with waitlist CTA and parody disclaimer" "phase-1,frontend,design" "$(cat <<'EOF'
## Summary
Marketing landing at `/` with mobile-first layout.

## References
- `docs/DESIGN.md` §8.1, §8.4 Mobile landing
- `docs/REQUIREMENTS.md` §5 Parody disclaimer, §6 Waitlist

## Tasks
- [ ] Hero: Space Grotesk headline, CT copy, meme accent sparingly
- [ ] Waitlist form (email + optional wallet from Privy if connected)
- [ ] Parody disclaimer section (Source Sans 3, 16px)
- [ ] Sticky bottom "Connect wallet" bar on mobile
- [ ] Desktop: split hero layout

## Acceptance criteria
- Responsive at sm/md/lg/xl breakpoints
- Waitlist submission works end-to-end
EOF
)"

create_issue "Deploy LiveKit server on Coolify" "phase-1,voice,infra" "$(cat <<'EOF'
## Summary
Self-hosted LiveKit SFU on Hetzner (or document LiveKit Cloud fallback).

## References
- `docs/DESIGN.md` §4, §11.1, §16

## Tasks
- [ ] Coolify service `legend-room-livekit`
- [ ] UDP/WebRTC ports + TURN if needed
- [ ] TLS `wss://livekit.` subdomain
- [ ] API key + secret in secrets store
- [ ] Document `NEXT_PUBLIC_LIVEKIT_URL`

## Acceptance criteria
- LiveKit health check passes
- Two test clients can join same room (raw audio, no dub)
EOF
)"

create_issue "Implement BFF LiveKit token mint on room join" "phase-1,voice,backend" "$(cat <<'EOF'
## Summary
Server-side LiveKit JWT with wallet identity and skin metadata.

## References
- `docs/DESIGN.md` §3.3, §6 LiveKit token claims

## Tasks
- [ ] Use `livekit-server-sdk` in BFF
- [ ] Claims: `sub` = wallet, room name, metadata `{ skin, display_name, can_publish }`
- [ ] TTL 1 hour; room-scoped
- [ ] Only callable after session + gate checks

## Acceptance criteria
- Token allows publish/subscribe in named room
- Metadata readable by voice worker
EOF
)"

create_issue "LiveKit client POC — raw multi-user voice (no dub)" "phase-1,voice,frontend" "$(cat <<'EOF'
## Summary
Validate WebRTC path before voice worker integration.

## References
- `docs/DESIGN.md` §3.4, Phase 1
- `docs/REQUIREMENTS.md` MVP checklist item 1

## Tasks
- [ ] Install `livekit-client`, `@livekit/components-react`
- [ ] Minimal `/rooms/[slug]/live` page
- [ ] Connect with BFF token; publish mic
- [ ] Hear other participants (undubbed)
- [ ] Mic permission priming screen

## Acceptance criteria
- Two browsers in same room hear each other
- Mute/unmute works
EOF
)"

# ─── Phase 2: Voice ──────────────────────────────────────────────────────────

create_issue "Implement GET /api/voice-skins" "phase-2,backend,voice" "$(cat <<'EOF'
## Summary
Public API listing enabled voice skins with preview URLs.

## References
- `docs/DESIGN.md` §6

## Tasks
- [ ] Return slug, label, preview_url for `enabled=true` skins
- [ ] Cache response 60s

## Acceptance criteria
- Frontend skin picker consumes this endpoint
EOF
)"

create_issue "Build room lobby UI with voice skin picker" "phase-2,frontend,design" "$(cat <<'EOF'
## Summary
Pre-join page at `/rooms/[slug]` with skin selection and disclaimer ack.

## References
- `docs/DESIGN.md` §8.1, §8.2, §8.4

## Tasks
- [ ] Fetch room detail + gate hint (`GET /api/rooms/:slug`)
- [ ] Skin picker: mobile horizontal scroll / bottom sheet; desktop 3-col grid
- [ ] Bungee skin labels; parody sublabel
- [ ] Disclaimer checkbox required before Join
- [ ] Join calls `POST /api/rooms/:slug/join`

## Acceptance criteria
- User cannot join without skin + disclaimer
- Layout matches mobile/desktop spec
EOF
)"

create_issue "Implement POST /api/rooms/:slug/join (gate, disclaimer, session)" "phase-2,backend,auth" "$(cat <<'EOF'
## Summary
Full join orchestration before LiveKit connect.

## References
- `docs/DESIGN.md` §3.3, §6

## Tasks
- [ ] Require BFF session
- [ ] Gate check: open | holder | allowlist | invite
- [ ] Validate `voice_skin` slug
- [ ] Create `room_sessions` with `disclaimer_accepted: true`
- [ ] Return LiveKit token + room config

## Acceptance criteria
- Gated room rejects ineligible wallet with clear error
- Session row created on successful join
EOF
)"

create_issue "Scaffold voice-worker service (LiveKit subscribe loop)" "phase-2,voice,infra" "$(cat <<'EOF'
## Summary
GPU worker process subscribing to participant audio tracks.

## References
- `docs/DESIGN.md` §7.1

## Tasks
- [ ] New service `services/voice-worker` (Python or Node + native)
- [ ] Connect to LiveKit server SDK
- [ ] Map `participant_id → { skin, buffer }` from token metadata
- [ ] Subscribe to incoming audio tracks
- [ ] Logging + graceful shutdown

## Acceptance criteria
- Worker logs participant join with skin metadata
- Receives audio frames from test publisher
EOF
)"

create_issue "ElevenLabs interim voice backend in voice-worker" "phase-2,voice" "$(cat <<'EOF'
## Summary
Interim dubbing via ElevenLabs real-time API.

## References
- `docs/DESIGN.md` §3.5, §7.3
- `docs/REQUIREMENTS.md` Legend voice skins interim fallback

## Tasks
- [ ] `VOICE_BACKEND=elevenlabs` env flag
- [ ] Map skin slug → `elevenlabs_voice_id` from PocketBase or env
- [ ] Stream PCM chunks to ElevenLabs; receive dubbed audio
- [ ] Republish dubbed track to LiveKit

## Acceptance criteria
- Single user hears dubbed output in test room
- Fallback documented in README
EOF
)"

create_issue "RVC inference sidecar HTTP API" "phase-2,voice,infra" "$(cat <<'EOF'
## Summary
Self-hosted RVC infer endpoint on GPU volume.

## References
- `docs/DESIGN.md` §7.2

## Tasks
- [ ] Docker image: Python + CUDA + RVC inference subset
- [ ] `POST /infer` — `{ skin, pcm_base64, sample_rate }` → dubbed pcm
- [ ] Models volume `/models/{slug}.pth`
- [ ] Health + GPU check endpoint

## Acceptance criteria
- Murad model returns converted audio for sample WAV
- Inference logged with duration ms
EOF
)"

create_issue "Wire voice-worker to RVC sidecar (VOICE_BACKEND=rvc)" "phase-2,voice" "$(cat <<'EOF'
## Summary
Primary voice path using RVC instead of ElevenLabs.

## References
- `docs/DESIGN.md` §3.4, §7.2, §7.3

## Tasks
- [ ] Chunk audio 20–40ms at 48kHz
- [ ] Call RVC sidecar per chunk; buffer output
- [ ] Publish dubbed LiveKit track
- [ ] Skin change: drain buffer, switch model

## Acceptance criteria
- p95 infer latency logged; target ≤170ms on GPU
- Intelligible speech in test room
EOF
)"

create_issue "Prepare RVC parody models for Ansem, Murad, Toly" "phase-2,voice" "$(cat <<'EOF'
## Summary
Train or obtain `.pth` models from public CT clips (parody only).

## References
- `docs/REQUIREMENTS.md` §2, Legal & Brand
- `docs/DESIGN.md` §7.2

## Tasks
- [ ] Collect ≤10min clean clips per persona (public sources)
- [ ] Train RVC models; export to `/models/{slug}.pth`
- [ ] Upload preview clips for `voice_skins.preview_url`
- [ ] Document parody training provenance internally

## Acceptance criteria
- Three models load in sidecar
- Preview clips playable on skin picker
EOF
)"

create_issue "Murad vs Toly two-user dubbed voice demo" "phase-2,voice,frontend" "$(cat <<'EOF'
## Summary
Flagship demo: two users arguing in different legend voices.

## References
- `docs/REQUIREMENTS.md` Demo Scenario
- `docs/DESIGN.md` §17 Demo acceptance criteria

## Tasks
- [ ] Room `sol-debate` seeded and live
- [ ] User A → Murad skin; User B → Toly skin
- [ ] Each hears the other dubbed
- [ ] 5+ minute stable session
- [ ] Screen recording for marketing

## Acceptance criteria
- All items in DESIGN.md §17 satisfied
EOF
)"

# ─── Phase 3: Gates & polish ─────────────────────────────────────────────────

create_issue "Implement Solana holder check in BFF" "phase-3,backend,auth" "$(cat <<'EOF'
## Summary
On-chain SPL token balance verification for holder-gated rooms.

## References
- `docs/DESIGN.md` §9.1, §9.2

## Tasks
- [ ] `getTokenAccountsByOwner` via `SOLANA_RPC_URL`
- [ ] Sum UI amount ≥ `rooms.min_balance`
- [ ] Cache 60s per wallet+mint
- [ ] Clear error messages for failed gate

## Acceptance criteria
- Holder room allows wallet with sufficient balance
- Non-holder rejected with 403 + reason
EOF
)"

create_issue "Implement allowlist and invite room gate types" "phase-3,backend" "$(cat <<'EOF'
## Summary
Non-holder gating mechanisms.

## References
- `docs/DESIGN.md` §9.2

## Tasks
- [ ] `allowlist`: check `room_allowlist` for wallet
- [ ] `invite`: signed JWT or one-time code validation
- [ ] Admin/BFF endpoint to add allowlist entries (host only)

## Acceptance criteria
- Each gate type tested with positive and negative cases
EOF
)"

create_issue "Build GET /api/rooms and /rooms browse page" "phase-3,frontend" "$(cat <<'EOF'
## Summary
List live and upcoming rooms.

## References
- `docs/DESIGN.md` §8.1

## Tasks
- [ ] `GET /api/rooms` — filter by status, public fields only
- [ ] `/rooms` page: cards with name, status, gate type badge, sponsor_label
- [ ] Empty state + loading skeletons

## Acceptance criteria
- Live rooms show "LIVE" chip (`accent-sol`, Bungee)
EOF
)"

create_issue "Implement POST /api/rooms (host create room)" "phase-3,backend" "$(cat <<'EOF'
## Summary
Authenticated hosts can create rooms.

## References
- `docs/DESIGN.md` §6

## Tasks
- [ ] Validate slug uniqueness, gate_type fields
- [ ] Set `host` from session user
- [ ] Default `max_participants: 10`, `livekit_room: slug`

## Acceptance criteria
- Host user creates holder-gated room with mint + min_balance
EOF
)"

create_issue "In-room UI — mobile sticky control bar" "phase-3,frontend,design" "$(cat <<'EOF'
## Summary
Mobile live room controls per design spec.

## References
- `docs/DESIGN.md` §8.4 Mobile live room, §8.5

## Tasks
- [ ] Horizontal participant avatar strip
- [ ] Sticky bottom: mute, deafen, leave (48×48px min)
- [ ] Circular primary mic button (`radius-full`)
- [ ] Collapsible parody disclaimer chip
- [ ] `safe-area-inset` padding

## Acceptance criteria
- Usable one-handed on iPhone Safari
- No hover-only actions
EOF
)"

create_issue "In-room UI — desktop sidebar and floating controls" "phase-3,frontend,design" "$(cat <<'EOF'
## Summary
Desktop layout for live room.

## References
- `docs/DESIGN.md` §8.4 Desktop

## Tasks
- [ ] Left sidebar: participant list, skin badge (Bungee), speaking glow
- [ ] Center stage: room title / optional visualizer
- [ ] Floating pill control bar (`radius-full`)
- [ ] `prefers-reduced-motion` disables pulse animation

## Acceptance criteria
- Layout at lg+ matches spec; mobile unchanged
EOF
)"

create_issue "Parody disclaimer UX — landing, lobby, in-room persistent banner" "phase-3,frontend,legal,design" "$(cat <<'EOF'
## Summary
Legal parody labeling across all touchpoints.

## References
- `docs/REQUIREMENTS.md` Legal & Brand, §5 Parody disclaimer
- `docs/DESIGN.md` §8.5

## Tasks
- [ ] Landing legal section
- [ ] Lobby checkbox + copy before join
- [ ] In-room persistent `warning` banner
- [ ] Store `disclaimer_accepted_at` on user + per-session flag
- [ ] Voice skin cards show "(Parody)" in label

## Acceptance criteria
- Cannot join without ack
- Banner visible entire session
EOF
)"

create_issue "WCAG AA contrast audit on all pages" "phase-3,design,frontend" "$(cat <<'EOF'
## Summary
Verify accessibility contrast before launch.

## References
- `docs/DESIGN.md` §8.3 Color

## Tasks
- [ ] Run contrast checker on all text/background pairs
- [ ] Fix any failing combinations
- [ ] Keyboard nav through join flow
- [ ] Focus rings visible on all controls

## Acceptance criteria
- Body text ≥4.5:1 on surfaces
- Large text and UI components ≥3:1
- Document results in PR or `docs/A11Y.md`
EOF
)"

create_issue "Deploy full stack on Coolify (web, PB, LiveKit, voice-worker)" "phase-3,infra" "$(cat <<'EOF'
## Summary
Production-like deployment on Hetzner via Coolify.

## References
- `docs/DESIGN.md` §11

## Tasks
- [ ] Services: `legend-room-web`, `legend-room-pocketbase`, `legend-room-livekit`, `legend-room-voice-worker`
- [ ] Traefik TLS: `app.`, `api.`, `livekit.`
- [ ] All env vars from §11.2 configured
- [ ] Volumes mounted
- [ ] Smoke test: landing → auth → join → voice

## Acceptance criteria
- Public URL serves landing page
- End-to-end join works on production URLs
EOF
)"

create_issue "Host manual kick / mute via LiveKit server API" "phase-3,backend,voice" "$(cat <<'EOF'
## Summary
Room host can remove disruptive participants (MVP moderation).

## References
- `docs/DESIGN.md` §10

## Tasks
- [ ] `POST /api/moderation/flag` or `/api/rooms/:slug/kick`
- [ ] Verify caller is room host or admin
- [ ] LiveKit API: remove participant or mute track
- [ ] Write `moderation_events` record

## Acceptance criteria
- Host kicks user; kicked user sees "ended" state
EOF
)"

# ─── Phase 4: Hardening ────────────────────────────────────────────────────────

create_issue "RVC cutover and ElevenLabs deprecation path" "phase-4,voice" "$(cat <<'EOF'
## Summary
Switch default `VOICE_BACKEND` to RVC when acceptance tests pass.

## References
- `docs/DESIGN.md` §7.3
- `docs/REQUIREMENTS.md` Open Questions (ElevenLabs cutover)

## Tasks
- [ ] Define acceptance: p95 ≤250ms, 10min stability, demo quality sign-off
- [ ] Set `VOICE_BACKEND=rvc` in production
- [ ] Keep ElevenLabs as documented fallback flag
- [ ] Update CHANGELOG

## Acceptance criteria
- Production runs RVC by default
- ElevenLabs path still works if flag set
EOF
)"

create_issue "LLM moderation worker hook (async, non-blocking)" "phase-4,backend" "$(cat <<'EOF'
## Summary
Schema + stub for automated moderation pipeline.

## References
- `docs/DESIGN.md` §10
- `docs/REQUIREMENTS.md` §7 LLM moderation

## Tasks
- [ ] `moderation-worker` service skeleton
- [ ] Policy prompt + LLM client (provider TBD)
- [ ] On violation: `moderation_events` + optional auto-mute (feature flag off by default)
- [ ] Defer STT; manual host kick remains primary

## Acceptance criteria
- Worker runs and logs; no impact on voice latency
- Feature flag documented
EOF
)"

create_issue "Observability — voice latency, join failures, GPU metrics" "phase-4,infra" "$(cat <<'EOF'
## Summary
Basic metrics and structured logging.

## References
- `docs/DESIGN.md` §14

## Tasks
- [ ] Voice worker: histogram `infer_duration_ms`
- [ ] BFF: structured logs on join failures (gate reason)
- [ ] LiveKit room count via metrics or logs
- [ ] GPU util on Hetzner box (node exporter optional)
- [ ] Coolify log drain configured

## Acceptance criteria
- Can answer "why did join fail?" from logs
- p95 voice latency visible after test session
EOF
)"

create_issue "Draft ToS and Privacy Policy (voice + wallet data)" "phase-4,legal" "$(cat <<'EOF'
## Summary
Legal pages before public launch.

## References
- `docs/REQUIREMENTS.md` Legal & Brand

## Tasks
- [ ] ToS page: parody voices, user conduct, no endorsement
- [ ] Privacy Policy: wallet address, voice not persisted v1, Privy data
- [ ] Link from landing footer and join flow
- [ ] Review voice data retention stance

## Acceptance criteria
- `/terms` and `/privacy` published
- Linked from disclaimer flow
EOF
)"

create_issue "Waitlist invite batch and launch metrics dashboard" "phase-4,frontend,backend" "$(cat <<'EOF'
## Summary
Early access rollout and v1 success metrics.

## References
- `docs/REQUIREMENTS.md` Success Metrics
- `docs/DESIGN.md` Phase 4

## Tasks
- [ ] Admin script: mark `waitlist.invited`, send emails (or manual)
- [ ] Track: waitlist signups, wallet connects, rooms joined, session duration
- [ ] Simple admin view or PB filters for counts
- [ ] Demo video embedded on landing

## Acceptance criteria
- Metrics defined and queryable
- First invite batch sent
EOF
)"

create_issue "Epic: Solana Dub Room MVP (tracker)" "phase-1,phase-2,phase-3,phase-4" "$(cat <<'EOF'
## Summary
Parent tracker for Solana Dub Room MVP — live voice chat with parody CT legend skins.

## Docs
- [REQUIREMENTS.md](https://github.com/THL007/legend-room/blob/main/docs/REQUIREMENTS.md)
- [DESIGN.md](https://github.com/THL007/legend-room/blob/main/docs/DESIGN.md)

## MVP checklist (from REQUIREMENTS)
- [ ] Live multi-user voice room (WebRTC / LiveKit)
- [ ] Real-time voice dubbing (RVC; ElevenLabs interim)
- [ ] 3+ legend voice skins (Ansem, Murad, Toly)
- [ ] Privy wallet auth + room entry
- [ ] At least one wallet-gated community room
- [ ] Parody disclaimer on landing and in-room
- [ ] Waitlist landing page
- [ ] Demo: Murad vs Toly debate
- [ ] Basic LLM moderation hook

## Phases
| Week | Focus |
|------|-------|
| 1 | Skeleton: Next.js, Privy, PocketBase, LiveKit raw voice |
| 2 | Voice worker, skin picker, Murad vs Toly demo |
| 3 | Holder gates, responsive UI, Coolify deploy |
| 4 | RVC cutover, moderation hook, metrics, legal |

## Definition of done
See DESIGN.md §17 — Murad vs Toly demo acceptance criteria.
EOF
)"

echo "Done."

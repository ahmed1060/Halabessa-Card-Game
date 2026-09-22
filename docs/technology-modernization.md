# Halabessa release technology architecture

Status: accepted, implementation in progress.

## Product goal

Halabessa should feel like a polished live card game while remaining operable
on the current free services. Technology is split by responsibility so that
the visual client cannot become a second source of game truth.

## Target architecture

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Application shell | Flutter | Navigation, identity UI, rooms, social, store, settings, accessibility and platform integration |
| Game presentation | Unity 6 | Board rendering, card interaction, animation, particles, audio cues and haptics; consumes snapshots and emits player intent only |
| Trusted game API | Supabase Edge Functions | Authenticate Firebase users, validate room and match commands, serialize concurrent actions and publish authoritative results |
| Private persistence | Supabase Postgres (`halabessa` schema) | Social graph, economy, configuration, audit/replay metadata and future match records; not exposed to the Data API |
| Game assets | Supabase Storage (`game-assets`) | Public delivery of avatars, store art and audio with MIME/size restrictions; all writes pass through the authenticated Edge API |
| Live match transport | Firebase Realtime Database (transition) | Low-latency snapshots, presence and chat. Clients subscribe; trusted gameplay state moves toward server-only writes |
| Identity | Firebase Authentication | Existing player identity and ID tokens, verified by the Supabase Edge Function |
| Web delivery | Firebase Hosting | Versioned Flutter/Unity WebGL release bundle and security headers |
| CI | GitHub Actions | Analysis, deterministic tests and web/Android/iOS release builds |

## Non-negotiable boundaries

1. Unity never authenticates with, reads from, or writes directly to a backend.
   `UnityBridge` is its only game-state input and player-intent output.
2. Online clients submit commands, not replacement match documents. The server
   validates membership, turn, phase, card ownership and action version.
3. Hidden information (deck order and opponents' hands) is never published in
   a public match snapshot. Each player receives only their permitted view.
4. Economy, rewards, administration and matchmaking decisions are server-owned.
5. Offline practice may use the Dart engine locally, but it must be visibly and
   structurally separate from ranked/online authority.
6. Every command is idempotent and versioned so reconnects and retries cannot
   play a card twice.

## Release sequence

### Foundation — now

- [x] Keep a single Flutter-to-Unity data path and remove the unused Unity
  Firebase SDK/listener.
- [x] Make CI consume Git LFS Unity binaries and verify their archive
  signatures.
- [x] Keep Firebase Hosting deploys serialized and independently reproducible.
- [x] Remove Firebase Storage from every client and route asset uploads through
  the server-authorized Supabase Storage gateway.
- [x] Back every newly created online room with a private Postgres authority
  record, private secrets row and monotonic version. Synchronize joins under a
  row lock and cascade administrative deletion through both data stores.
- [x] Add a private idempotent command ledger keyed by room and command UUID;
  browser roles have neither table grants nor an allow policy.
- Regenerate the checked-in Android and iOS Unity exports from the cleaned
  Unity source before store submission, removing the temporary legacy Firebase
  resource compatibility code from the iOS Podfile.

### Authoritative multiplayer

- [x] Add a versioned, idempotent Edge command endpoint for `startRound`,
  `cut`, initial/subsequent dealing, beginning play and `playCard`. Commands
  are serialized under a room row lock and validate membership, phase, turn,
  dealer/cutter authority and card ownership.
- [x] Store the deck, all hands and action version in private server storage.
  Public command responses contain hand counts plus only the authenticated
  caller's hand.
- [ ] Route the Flutter online controller through the command endpoint while
  retaining the Dart engine only for explicitly offline practice. The client
  now carries `serverVersion`, public hand counts and a typed command transport;
  controller mutation routing remains to be switched as one atomic change.
- [ ] Move votes, timeouts, end-of-round settlement and full match scoring into
  the trusted engine.
- [ ] Stop mirroring complete hands during the transition, subscribe each
  client only to its permitted view, then lock RTDB gameplay writes to the
  backend service account.
- [ ] Add deterministic engine fixtures shared between client expectations and the
  server, plus concurrency and replay tests.

### Live operations and quality

- Version balance/timer configuration in private Postgres and cache a signed
  read-only release document.
- Add structured match telemetry, crash reporting, latency/error budgets and a
  kill switch for unstable queues or modes.
- Add reconnect, packet-loss, duplicate-command and four-client load tests.

### Presentation polish

- Replace placeholder card geometry/materials with optimized atlased assets,
  object pooling and a consistent animation timeline.
- Add scalable VFX/audio quality tiers, reduced-motion support, color-safe
  suit indicators and performance budgets for low/mid/high devices.
- Gate new effects and modes behind server-controlled release flags.

## Definition of release-ready

- Web, Android and iOS release builds are green from a clean checkout.
- No online gameplay mutation is accepted directly from a player client.
- A complete match can be reconstructed from its ordered command log.
- Reconnect and duplicate requests preserve exactly one authoritative outcome.
- The game holds its target frame time on the agreed minimum device tier and
  reports crashes, backend errors and match abandonment rates.

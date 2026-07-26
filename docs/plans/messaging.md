# In-app messaging — implementation plan

Last updated: 2026-07-25

Feature flag: `featureFlags.messagesEnabled` (web) / `AppConstants.messagesEnabled` (Flutter) — **on** after M5/M6 minimum path.

**Formula:** overall = sum of completed sub-weights across phases M0–M7 (weights total 100%). Track Backend / Flutter / Angular checkboxes per phase.

Related: privacy-first Trust Alias, booking client visibility, [docs/web/implementation.md](../web/implementation.md).

---

## 1. Product rules

### 1.1 User ↔ user (direct) — anti-enumeration invites

- Initiator submits a target **email**, **phone**, or **trust alias**.
- **API always returns the same opaque success** (same status + copy), whether or not a matching user exists — e.g. “If this person is on Vaxiil, an invitation will be sent.” Initiator **never** learns existence, online status, or profile from the invite flow.
- **Server-side only:** if a user matches, create a **pending invitation**; if not, no-op. Timing should be roughly constant (avoid timing oracles). Rate-limit invite submits.
- Recipient notification (when invite exists) must state that the **requester cannot see whether they are on the platform until they accept**. Decline / ignore / block: requester still gets no existence signal.
- Until accepted: no chat content; only the invite notice to the recipient.
- After accept: 1:1 direct thread. Peers shown primarily by trust alias unless they share real identity via prefs.

### 1.2 Company ↔ user (constrained)

Companies may **not** open arbitrary DMs with users. Only:

| Thread type | Who can open | Scope |
|-------------|--------------|--------|
| **Booking thread** | Org staff **or** client, once a booking exists | Tied to `booking_id` |
| **Support ask** | **User only** starts | User picks org; org staff may reply afterward |

No cold outreach from company → user outside booking/support.

### 1.3 Attribution on org-side messages

- Persist `sender_user` + `sender_membership` on each staff message.
- **Client-facing payload** shows that member’s **trust alias** only (not legal name/email/phone).
- Internal org UI may show richer staff identity for the company’s own team.

### 1.4 Thread block / unblock

- Any participant can **block** a conversation until they **unblock**.
- While blocked by either side: **neither** side can **send** new messages (clear “blocked” error). Blocker may still read history.
- Unblock restores send (if conversation still `active`).
- Blocking a **pending P2P invite** = decline + block (suppress further invites from that peer until unblock).

### 1.5 Alias regeneration

- `POST /auth/regenerate-alias/` invalidates old lookup key.
- Pending P2P invites addressed to the old alias fail closed (expire or require re-invite with new alias).

### 1.6 Privacy rationale

Messaging exists so companies and users can coordinate **without exchanging phone numbers**. Prefer trust aliases in UI; never dump contact fields into thread lists.

---

## 2. Phased progress (97% / 100%)

| Phase | Weight | Status |
|-------|--------|--------|
| M0 Domain | 15% | done |
| M1 Lookup + invites API | 15% | done |
| M2 Org threads API | 15% | done |
| M3 Messaging API | 15% | done |
| M4 Transport | 10% | done (polling) |
| M5 Flutter | 15% | done (minimum path) |
| M6 Angular | 12% | done |
| M7 Hardening | 3% | partial (i18n + alias invalidation; abuse/push stretch) |
| **Overall** | **100%** | **~97%** |

### Phase M0: Domain (15% / 15%)

- [x] `Conversation` (`kind`: `direct` \| `booking` \| `support` \| `platform`; status `pending`/`active`/`declined`/`closed`/`blocked`)
- [x] `ConversationParticipant` (per-side `blocked_at`)
- [x] `Message` (`sender_user`, optional `sender_membership`)
- [x] `ConversationInvite` for P2P
- [x] Soft-delete; unread receipts (`last_read_at`)
- [x] Migrations + model/API tests

### Phase M1: Lookup + invites API (15% / 15%)

- [x] Opaque invite-submit (no existence leak; constant-ish timing)
- [x] Create pending invite only if user exists
- [x] Accept / decline
- [x] Recipient copy about requester blindness
- [x] Rate limits (cache)
- [x] API tests for anti-enumeration

### Phase M2: Org threads API (15% / 15%)

- [x] Open/list booking thread
- [x] User-starts support thread
- [x] Staff reply with membership attribution
- [x] Permission matrix tests

### Phase M3: Messaging API (15% / 15%)

- [x] List threads, list/send messages, mark read
- [x] Block / unblock (send denied when either side blocked)
- [x] Privacy-safe serializers (aliases; no phone dump)
- [x] Tests

### Phase M4: Transport (10% / 10%)

- [x] Polling first (list + messages since cursor)
- [ ] WebSocket/SSE later (optional stretch)

### Phase M5: Flutter (15% / 15%)

- [x] Replace stub `messages_page`
- [x] Invites inbox
- [x] Thread UI + block/unblock
- [ ] Booking “Message” + user “Ask support” entry points (API ready; UI CTA follow-up)
- [x] Show staff aliases
- [x] Widget/unit tests (model parse)

### Phase M6: Angular (12% / 12%)

- [x] Consumer `/messages` (Stitch: inbox, thread, invite)
- [x] Business booking/support inbox
- [x] Block/unblock
- [x] Gate on `featureFlags.messagesEnabled`
- [x] Unit tests

### Phase M7: Hardening (2% / 3%)

- [x] i18n (en/fr)
- [x] Regenerate-alias invite invalidation
- [ ] Abuse limits beyond invite rate / push hooks stub
- [x] Triple-sync checklist in web impl doc

---

## 3. API (shipped under `/api/v1/messaging/`)

| Method | Path | Notes |
|--------|------|-------|
| POST | `/messaging/invites/` | Opaque ACK; body `{ email? \| phone? \| trust_alias? }` |
| GET | `/messaging/invites/incoming/` | Recipient’s pending invites |
| POST | `/messaging/invites/{id}/accept/` | Reveal presence + open thread |
| POST | `/messaging/invites/{id}/decline/` | optional `{ block }` |
| GET | `/messaging/conversations/` | User’s threads; `?organization_id=` for org inbox |
| POST | `/messaging/conversations/booking/` | `{ booking_id }` get-or-create |
| POST | `/messaging/conversations/support/` | `{ organization_id }` user-only |
| POST | `/messaging/conversations/platform-support/` | optional `{ user_id }` (staff) or self |
| GET/POST | `/messaging/conversations/{id}/messages/` | List (`?since=`) / send |
| POST | `/messaging/conversations/{id}/block/` | |
| POST | `/messaging/conversations/{id}/unblock/` | |
| POST | `/messaging/conversations/{id}/read/` | |

Sender shape (client): `{ kind: "user" \| "org_member", trust_alias, membership_id? }` + `is_mine` on messages.

---

## 4. UI entry points

| Surface | Entry |
|---------|--------|
| Consumer messages | `/messages` (Flutter + Angular) |
| P2P invite | Compose by email / phone / alias |
| Booking detail | “Message” → booking thread (API ready) |
| Org / consumer | “Ask support” (API ready) |
| Business inbox | `/business/:orgId/messages` |
| Thread detail | Block / Unblock |

Stitch: [`docs/design/stitch/messages/`](../design/stitch/messages/).

---

## 5. Triple-sync checklist

When messaging APIs ship:

1. Backend serializers/views + `uv run pytest` — done (`src/apps/messaging/tests/`)
2. Flutter models/repos + `flutter test` — done (`test/messaging_models_test.dart`)
3. Angular models/services + `yarn test:ci` / `yarn lint` — done
4. Update this doc checkboxes/% and [docs/web/implementation.md](../web/implementation.md) messaging gap row
5. Flip feature flags when M5+M6 minimum path works — **done**

# Sumsub KYC setup

User identity verification uses [Sumsub](https://sumsub.com/). Postman-style request signing examples live in [`sumsub.json`](./sumsub.json). Flutter plugin docs: [Flutter plugin](https://docs.sumsub.com/docs/flutter-plugin).

## Environment

| Variable | Purpose |
|----------|---------|
| `SUMSUB_APP_TOKEN` | Dashboard App Token |
| `SUMSUB_SECRET_KEY` | Dashboard Secret Key (request HMAC) |
| `SUMSUB_BASE_URL` | Default `https://api.sumsub.com` |
| `SUMSUB_LEVEL_NAME` | Verification level name (default `basic-kyc-level`) |
| `SUMSUB_CUSTOMIZATION_NAME` | WebSDK permalink `customizationName` query param (default `vaxiil-web`; empty disables) |
| `SUMSUB_WEBHOOK_SECRET` | Webhook manager secret (`X-Payload-Digest`) |
| `SUMSUB_REDIRECT_SIGN_KEY` | HMAC key for WebSDK redirect JWT (`redirect.signKey` on link generation; verified on return) |
| `SUMSUB_SEND_PERSONAL_DATA` | `True`/`False` — include user email/phone as Sumsub `applicantIdentifiers` on WebSDK links (default `False`) |
| `SUMSUB_WEB_SUCCESS_URL` | Default Angular success redirect |
| `SUMSUB_WEB_REJECT_URL` | Default Angular reject redirect |

Generate a long random `SUMSUB_REDIRECT_SIGN_KEY` (≥32 bytes recommended for HS256) and keep it identical in env and (implicitly) on every websdk-link call via Django settings.

## Dashboard

1. Create a verification level (ID + selfie / liveness as required).
2. Create an App Token + Secret Key; put them in env.
3. Webhooks → add `https://<api-host>/api/v1/auth/webhooks/sumsub/` with digest alg `HMAC_SHA256_HEX`. Subscribe at least to the **handled** types below (others may be enabled; they are ACK'd and ignored).

### Client redirect origins

- **Angular (dev):** set `kycRedirectOrigin` in [`web/src/environments/environment.development.ts`](../../web/src/environments/environment.development.ts) (no trailing slash). Production builds use `window.location.origin`.
- **Flutter web (non-release):** `--dart-define=KYC_REDIRECT_ORIGIN=https://your-tunnel` (see `AppConstants.kycRedirectOrigin`). Release builds use `Uri.base.origin`.

## Webhook event handling

All events must pass `X-Payload-Digest` verification. User is resolved by `externalUserId` (= Vaxiil user UUID). Status maps onto existing codes `P` / `V` / `R` only.

| Outcome | Event `type` values |
|---------|---------------------|
| **Pending (`P`)** | `applicantPending`, `applicantCreated`, `applicantOnHold`, `applicantAwaitingUser`, `applicantAwaitingService`, `applicantReset`, `applicantStepsReset` |
| **Verified (`V`)** | `applicantReviewed`, `applicantWorkflowCompleted` when `reviewResult.reviewAnswer` is `GREEN` |
| **Rejected (`R`)** | Same review/workflow-completed events when answer is `RED`; always `applicantWorkflowFailed` |
| **ACK ignored** | Action / tags / personal-info / share-token / link-opened / activated / deactivated / deleted / level-changed; KYT (`kytCaseV2*`, often no `externalUserId`) |

`applicantId` is stored on `User.sumsub_applicant_id` whenever present and the user resolves.

## Redirect return sync

After WebSDK finishes, Sumsub redirects to success/reject URLs and appends query params such as `status`, `jwt`, and `sbx`.

Example:

`/profile/verify/return?status=ok&jwt=...&sbx=true`

Decoded redirect JWT (HS256 with `SUMSUB_REDIRECT_SIGN_KEY`):

```json
{
  "iat": 1785099434,
  "exp": 1785100034,
  "sub": "<user-uuid>",
  "aud": "bapimagine.com",
  "status": "approved"
}
```

Clients **POST** those params to the return endpoint (do not trust `status` alone). The API:

1. Verifies JWT (`sub` must equal the authenticated user; `exp` enforced; `aud` is not used for auth). Expired JWT returns `400` with `code: sumsub_redirect_jwt_expired` so clients can clear the session submitted flag and request a fresh WebSDK link.
2. Fetches the applicant via `GET /resources/applicants/-;externalUserId={externalUserId}/one`.
3. Persists a historic `UserKycSumsubEvent` (applicant payload JSON, review answer, sandbox flag).
4. Updates `verification_status` from applicant `review.reviewResult.reviewAnswer` (GREEN/RED) when present, else maps JWT `status` (`approved` → `V`, reject-like → `R`).
5. Lists document images and downloads identity + selfie into `User.id_document` / `User.selfie_document`.

Webhooks remain a second path to the same status fields.

## Vaxiil API

| Method | Path | Auth | Role |
|--------|------|------|------|
| `POST` | `/api/v1/auth/kyc/sumsub/access-token/` | JWT | Flutter Idensic SDK token (`externalUserId` = user UUID) |
| `POST` | `/api/v1/auth/kyc/sumsub/websdk-link/` | JWT | Returns `{ url }`; optional `success_url` / `reject_url` / `lang`; includes `redirect.signKey` when configured |
| `POST` | `/api/v1/auth/kyc/sumsub/return/` | JWT | Body `{ jwt, status?, sbx? }` → sync applicant + docs; returns profile JSON |
| `POST` | `/api/v1/auth/webhooks/sumsub/` | Public + digest | Updates `verification_status` / `sumsub_applicant_id` |

Staff approve/reject and legacy multipart `POST /api/v1/auth/verify/` remain available as overrides/fallback.

## Clients

- **Angular**: `/profile/verify` → websdk-link → browser redirect; return at `/profile/verify/return` calls `completeSumsubReturn` then shows status banners. If the redirect JWT is expired (`sumsub_redirect_jwt_expired`), clears `vaxiil_kyc_submitted` and requests a new WebSDK link automatically.
- **Flutter mobile**: `flutter_idensic_mobile_sdk_plugin` + access-token (+ token refresh).
- **Flutter web**: opens websdk-link via `url_launcher`; return route `/profile/verify/return` posts JWT then refreshes profile.

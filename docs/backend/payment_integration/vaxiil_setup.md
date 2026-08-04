# Vaxiil MM Aggregator payment configuration

This runbook configures **MM Aggregator** as the default collection gateway for Vaxiil (booking pay and store-credit top-up). MainMoney hosted payment links are deprecated.

Merchant API contracts (auth, deposits, status check, webhooks, payouts) are curated under [`docs/integrations/mm_aggregator/`](../../integrations/mm_aggregator/README.md).

The seed command creates **placeholder country MoMo rails** (`MOMO_CD`, `MOMO_CG`, `MOMO_BI`, …). For production in DRC, Congo Brazzaville, and Burundi, create **per-operator** `PaymentMethod` rows in Django admin with the FinancialEntity codes below. Do **not** rely on seed placeholders for live traffic.

## 1. Environment variables

Set these in `backend/.env` (see repo root `.env.example`):

| Variable | Purpose |
|----------|---------|
| `MM_AGGREGATOR_API_BASE` | Aggregator API origin (no trailing slash), e.g. `https://api.example.com` |
| `MM_AGGREGATOR_CLIENT_ID` | Merchant application `client_id` |
| `MM_AGGREGATOR_CLIENT_SECRET` | API key secret (token exchange) |
| `MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET` | Optional HMAC secret for inbound merchant webhooks |
| `PAYMENT_REDIRECT_BASE_URL` | Frontend origin (legacy MainMoney redirect; still used by redirect route) |

Credentials can also be stored on `PaymentProvider(code='mm_aggregator').config` as `client_id` / `secret`.

## 2. Database: provider + catalog seed

```bash
cd backend && uv run python manage.py seed_payment_catalog
```

This ensures:

- Active `PaymentProvider(code='mm_aggregator')`
- Inactive legacy `mainmoney` provider (if present)
- Placeholder MoMo `PaymentMethod` rows on connector `mm_aggregator` with `collect` / `wallet_fund` / `refund` ops and sample `config.provider_code` values

Then configure operator methods in admin (next section). Align every method’s `config.provider_code` with a live FinancialEntity code in MM Aggregator.

## 3. Per-operator PaymentMethod setup (Django admin)

Open **Payments → Payment methods** (or add methods under connector `mm_aggregator`).

### Recommended operator rails

| Country | Suggested method `code` | Display name (example) | `config.provider_code` | `supported_operations` |
|---------|-------------------------|------------------------|------------------------|------------------------|
| DRC (CD) | `AIRTEL_COD` | Airtel Money (DRC) | `AIRTEL_COD` | `collect`, `wallet_fund`, `refund`, `settlement`, `payout` |
| DRC (CD) | `VODACOM_MPESA_COD` | Vodacom M-Pesa (DRC) | `VODACOM_MPESA_COD` | `collect`, `wallet_fund`, `refund`, `settlement`, `payout` |
| DRC (CD) | `ORANGE_COD` | Orange Money (DRC) | `ORANGE_COD` | `collect`, `wallet_fund`, `refund`, `settlement`, `payout` |
| Congo (CG) | `AIRTEL_COG` | Airtel Money (Congo) | `AIRTEL_COG` | `collect`, `wallet_fund`, `refund`, `settlement`, `payout` |
| Congo (CG) | `MTN_MOMO_COG` | MTN MoMo (Congo) | `MTN_MOMO_COG` | `collect`, `wallet_fund`, `refund`, `settlement`, `payout` |
| Burundi (BI) | `BURUNDI_PAY` | Burundi Pay | `BURUNDI_PAY` | **`settlement`, `refund`, `payout` only** (send / outbound) |

**Burundi is send-only:** do **not** enable `collect` or `wallet_fund` on `BURUNDI_PAY`. Clients listing `?operation=collect` or `wallet_fund` will not see it; it is for business settlement accounts and outbound payout/refund rails only.

### Shared field values (each operator method)

| Field | Value |
|-------|--------|
| Connector | `mm_aggregator` |
| Method type | Mobile money (`M`) |
| Country | Matching Vaxiil country (CD / CG / BI) |
| Currency | Optional; leave blank unless the rail is currency-locked |
| Account regex | `^\+?[0-9]{8,15}$` (phone rails) |
| Active | Yes |

### `config` JSON (identifier UI + provider)

Clients read identifier UI metadata from `config` (and from brief API fields derived from it). Example for Airtel DRC:

```json
{
  "provider_code": "AIRTEL_COD",
  "destination_fields": ["phone_number", "account_name"],
  "optional_fields": ["account_name"],
  "identifier_type": "phone",
  "account_placeholder": {
    "en": "e.g. 97 000 0001",
    "fr": "ex. 97 000 0001"
  },
  "phone_country_codes": ["CD"]
}
```

| Key | Purpose |
|-----|---------|
| `provider_code` | MM Aggregator FinancialEntity code (required for collect / wallet_fund) |
| `destination_fields` | Logical destination keys (`phone_number`, `iban`, `interac_email`, …) |
| `optional_fields` | Subset of destination fields that may be empty |
| `identifier_type` | `phone` \| `email` \| `generic` — drives client input type (default `generic` if omitted) |
| `account_placeholder` | Localized `{ "en": "...", "fr": "..." }` shown in the account field |
| `phone_country_codes` | Optional ISO2 allowlist for the dial-code picker; omit or `[]` = all active countries |

For email rails (e.g. Interac-style), use `"identifier_type": "email"` and an email placeholder. For IBAN / free-form account numbers, use `"identifier_type": "generic"`.

Congo example (`phone_country_codes`: `["CG"]`). Burundi send-only example:

```json
{
  "provider_code": "BURUNDI_PAY",
  "destination_fields": ["phone_number", "account_name"],
  "optional_fields": ["account_name"],
  "identifier_type": "phone",
  "account_placeholder": {
    "en": "e.g. 79 000 000",
    "fr": "ex. 79 000 000"
  },
  "phone_country_codes": ["BI"]
}
```

With `supported_operations`: `["settlement", "refund", "payout"]`.

### After go-live

Optionally deactivate seed placeholders `MOMO_CD`, `MOMO_CG`, and `MOMO_BI` so clients only list the operator methods above.

## 4. Collection flow

1. Client lists methods: `GET /api/v1/payments/methods/?operation=collect` (or `wallet_fund`).
2. Client starts collection:
   - Booking: `POST /api/v1/payments/bookings/{id}/payment-link/` with `payment_method_id`, `account_identifier` (phone/email/account), optional `apply_wallet`
   - Wallet: `POST /api/v1/payments/wallet/top-up/` with `amount`, `currency_code`, `payment_method_id`, `account_identifier` (KYC required)
3. Response has **no hosted `url`** — status is pending/processing; payer confirms on their phone (STK/USSD) for MoMo collect.
4. MM Aggregator notifies Vaxiil when the deposit completes.
5. If the webhook is delayed, clients can pull status:
   - `POST /api/v1/payments/transactions/{client_reference}/refresh/`
   - Vaxiil calls MM Aggregator `POST /transactions/status/check/deposit/` with `{ "reference": "<client_reference>" }` and applies SUCCESS/FAILED via `apply_payment_outcome` (see [`transaction_status_check.md`](../../integrations/mm_aggregator/transaction_status_check.md)).

## 5. Webhook

```text
POST https://<your-api-host>/api/v1/payments/webhooks/mm_aggregator/
```

Configure this URL as the merchant webhook (or per-request `callback_url`). Expected payload fields include `merchant_reference` and `status` (`SUCCESS` / `FAILED` / …), optionally nested under `_mm_defaults`.

If `MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET` is set, send matching HMAC in `X-Mma-Signature` (same scheme as MainMoney helper).

On success: booking payments mark the transaction succeeded (status stays Requested until business confirms); wallet top-ups credit store credit.

## 6. Auth to MM Aggregator

Vaxiil exchanges credentials then calls merchant endpoints:

- `POST /api/v1/auth/tokens/exchange/`
- `POST /api/v1/transactions/deposits/`
- `POST /api/v1/transactions/status/check/deposit/`
- `POST /api/v1/transactions/refunds/`
- `POST /api/v1/transactions/payouts/`
- `POST /api/v1/transactions/payouts/business/`
- `POST /api/v1/transactions/payouts/business/merchant-account/`

### Settlement / refund / payout product status

| Capability | Product behavior today |
|------------|------------------------|
| Collect / wallet top-up | Wired through MM Aggregator deposits + webhook |
| Deposit status refresh | Wired: consumer `POST /payments/transactions/{ref}/refresh/` → adapter `check_deposit_status` |
| Booking cancellation refund | Credits **store credit** locally (does not call aggregator refund) |
| Business settlement | Staff **manual** complete/reject queue (adapter payout exists but is not auto-wired) |

`BURUNDI_PAY` and other send-only methods are for settlement account configuration and future outbound rails; they do not enable customer collect.

## 7. Smoke checklist

1. Env vars set; `seed_payment_catalog` run.
2. Admin: create CD/CG operator methods with correct `provider_code` + `identifier_type: phone`; create BI `BURUNDI_PAY` send-only.
3. Optionally deactivate `MOMO_CD` / `MOMO_CG` / `MOMO_BI`.
4. `GET /payments/methods/?operation=collect&country=CD` lists Airtel / Vodacom / Orange (not Burundi).
5. Create booking → collect with a CD/CG method + phone → pending transaction.
6. Simulate webhook SUCCESS → `is_paid: true`, status still Requested.
7. Optional: leave a collect pending, then `POST /payments/transactions/{ref}/refresh/` after provider SUCCESS → local status Succeeded.
8. Optional: KYC-verified wallet top-up + apply store credit on next booking.
9. Business settlement: attach a settlement account using a send-capable method (including `BURUNDI_PAY` for BI).

## Legacy MainMoney

Routes under `/api/v1/payments/webhooks/mainmoney/` and `/redirect/` remain for old transactions. Do not configure new collections against MainMoney.

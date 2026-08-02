# Vaxiil MM Aggregator payment configuration

This runbook configures **MM Aggregator** as the default collection gateway for Vaxiil (booking pay and store-credit top-up). MainMoney hosted payment links are deprecated.

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

## 2. Database: provider + catalog

```bash
cd backend && uv run python manage.py seed_payment_catalog
```

This ensures:

- Active `PaymentProvider(code='mm_aggregator')`
- Inactive legacy `mainmoney` provider (if present)
- MoMo `PaymentMethod` rows on connector `mm_aggregator` with `collect` / `wallet_fund` / `refund` ops and `config.provider_code`

Align each method’s `config.provider_code` with a live FinancialEntity code in MM Aggregator.

## 3. Collection flow

1. Client lists methods: `GET /api/v1/payments/methods/?operation=collect`
2. Client starts collection:
   - Booking: `POST /api/v1/payments/bookings/{id}/payment-link/` with `payment_method_id`, `account_identifier` (phone), optional `apply_wallet`
   - Wallet: `POST /api/v1/payments/wallet/top-up/` with `amount`, `currency_code`, `payment_method_id`, `account_identifier`
3. Response has **no hosted `url`** — status is pending/processing; payer confirms on their phone (STK/USSD).
4. MM Aggregator notifies Vaxiil when the deposit completes.

## 4. Webhook

```text
POST https://<your-api-host>/api/v1/payments/webhooks/mm_aggregator/
```

Configure this URL as the merchant webhook (or per-request `callback_url`). Expected payload fields include `merchant_reference` and `status` (`SUCCESS` / `FAILED` / …), optionally nested under `_mm_defaults`.

If `MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET` is set, send matching HMAC in `X-Mma-Signature` (same scheme as MainMoney helper).

On success: booking payments mark the transaction succeeded (status stays Requested until business confirms); wallet top-ups credit store credit.

## 5. Auth to MM Aggregator

Vaxiil exchanges credentials then calls merchant endpoints:

- `POST /api/v1/auth/tokens/exchange/`
- `POST /api/v1/transactions/deposits/`
- `POST /api/v1/transactions/refunds/`
- `POST /api/v1/transactions/payouts/`
- `POST /api/v1/transactions/payouts/business/`
- `POST /api/v1/transactions/payouts/business/merchant-account/`

## 6. Smoke checklist

1. Env vars set; `seed_payment_catalog` run; methods show `provider_code`.
2. Create booking → collect with MoMo method + phone → pending transaction.
3. Simulate webhook SUCCESS → `is_paid: true`, status still Requested.
4. Optional: wallet top-up + apply store credit on next booking.

## Legacy MainMoney

Routes under `/api/v1/payments/webhooks/mainmoney/` and `/redirect/` remain for old transactions. Do not configure new collections against MainMoney.

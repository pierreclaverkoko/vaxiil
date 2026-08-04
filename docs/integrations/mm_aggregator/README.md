# MM Aggregator (merchant API)

Vaxiil uses [MM Aggregator](https://github.com/) as the default collection gateway for booking payments and store-credit top-ups. Operational setup (env vars, PaymentMethod rails, seed) lives in [`docs/backend/payment_integration/vaxiil_setup.md`](../../backend/payment_integration/vaxiil_setup.md).

This folder curates the **merchant-facing** API surface from the MM Aggregator project (`mm_aggregator` admin API docs) so Vaxiil agents can check contracts without opening that repo.

## Documents

| Doc | Topic |
|-----|--------|
| [authentication.md](./authentication.md) | Token exchange + Bearer auth |
| [deposits.md](./deposits.md) | Customer → merchant collection |
| [transaction_status_check.md](./transaction_status_check.md) | Pull status from provider / refresh stored state |
| [webhooks.md](./webhooks.md) | Push status to merchant HTTPS endpoint |
| [payouts.md](./payouts.md) | Merchant → beneficiary payouts (future outbound) |

## Vaxiil wiring status

| MM Aggregator endpoint | Vaxiil adapter / route |
|------------------------|------------------------|
| `POST /auth/tokens/exchange/` | [`MmAggregatorPaymentAdapter._get_access_token`](../../../backend/src/apps/payments/adapters/mm_aggregator.py) |
| `POST /transactions/deposits/` | `collect()` — booking pay + wallet top-up |
| `POST /transactions/refunds/` | `refund()` (metadata-dependent) |
| `POST /transactions/payouts/` (+ business variants) | `payout` / `business_payout` (not auto-wired to settlement UI) |
| `POST /transactions/status/check/deposit/` | `check_deposit_status()` → `POST /api/v1/payments/transactions/{ref}/refresh/` |
| Merchant webhooks | `POST /api/v1/payments/webhooks/mm_aggregator/` (`X-Mma-Signature`) |

Base URL is `MM_AGGREGATOR_API_BASE` (no trailing slash). Adapter paths are relative (e.g. `/transactions/deposits/`), matching MM Aggregator’s `/api/v1/...` when the base already includes `/api/v1` or the gateway prefixes it — use the same base that works for deposits today.

## Source

Canonical merchant docs in the MM Aggregator repo:

`admin_frontend/src/app/pages/api-docs/` (transactions + getting-started).

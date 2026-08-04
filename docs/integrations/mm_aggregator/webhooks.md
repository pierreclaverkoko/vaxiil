# Webhooks

Transaction APIs often return while the provider is still processing. **Webhooks** are the primary asynchronous signal. Combine with [transaction status checks](./transaction_status_check.md) when reconciling missed callbacks.

## End-to-end flow

1. The payment provider calls MM Aggregator inbound URLs.
2. The platform stores a webhook event, updates the linked transaction when resolvable, then **forwards** a normalized JSON payload to your merchant webhook URL.

## Merchant endpoint requirements

| Requirement | Detail |
|-------------|--------|
| Method | `POST` |
| Content-Type | `application/json` |
| Acknowledgement | Return **HTTP 2xx** after accepting the event |
| Idempotency | Deduplicate with `webhook_event_id` / `X-Webhook-Event-ID` |
| Signature | Verify HMAC when a webhook secret is configured |

## Headers (outbound from MM Aggregator)

Typical platform headers include `X-Webhook-Event-ID`, `X-Webhook-Provider`, `X-Webhook-Type`, `X-Webhook-Timestamp`, and `X-Webhook-Signature` (HMAC-SHA256 hex of raw body bytes).

## Vaxiil receiver

Vaxiil exposes:

```text
POST /api/v1/payments/webhooks/mm_aggregator/
```

Implementation notes:

- Handler: `handle_mm_aggregator_webhook` in `backend/src/apps/payments/services/webhooks.py`.
- Signature header accepted: **`X-Mma-Signature`** (also falls back to MainMoney-style headers where configured).
- Secret: `MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET`.
- Expected payload fields include `merchant_reference` and `status` (`SUCCESS` / `FAILED` / …), optionally nested.
- On success: booking payments mark the transaction succeeded (`is_paid`); wallet top-ups credit store credit via `apply_payment_outcome`.

Configure this URL as the merchant webhook (or per-request `callback_url` on deposit create).

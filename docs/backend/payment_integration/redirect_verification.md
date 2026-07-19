---
title: Redirect verification
section: Payment links
order: 20
---

# Redirect verification

When you set `redirectUrl` on a payment link, payers return to your site after checkout with signed query parameters.

## Query parameters

| Parameter | Description |
| --- | --- |
| `reference` | Your `merchantReference` from link creation (public payment id) |
| `status` | `completed` or `failed` |
| `amount` | Settled amount |
| `currency` | Currency code |
| `timestamp` | Unix time in seconds |
| `signature` | HMAC-SHA256 hex digest |

Mainmoney does **not** expose internal payment-request UUIDs in redirect URLs.

## Verify the signature

1. Read `reference`, `status`, `amount`, `currency`, and `timestamp` from the query string.
2. Build the canonical payload (pipe-delimited, fixed order):

```
reference|status|amount|currency|timestamp
```

3. Compute `HMAC-SHA256(webhook_signing_secret, payload)` as lowercase hex.
4. Compare to the `signature` query parameter using a constant-time comparison.

Never trust `status` alone — always verify the signature before fulfilling an order.

## Sandbox fast path

For sandbox integration tests without a live payer, use `POST /developers/v1/payment-links/:id/simulate-complete` to receive the same redirect shape.

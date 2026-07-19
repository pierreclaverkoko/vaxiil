---
title: Webhook events
section: Webhooks
order: 10
endpoint: webhookVerification
---

# Webhook events

Configure `webhookUrl` on your app in the Developer dashboard.

## Headers

- `X-Mainmoney-Event`
- `X-Mainmoney-Signature` — HMAC-SHA256 of raw JSON body

## Events

- `payment_link.payment.completed`
- `payment_link.payment.failed`

## Payload shape

```json
{
  "event": "payment_link.payment.completed",
  "id": "...",
  "created": "2026-06-14T12:00:00.000Z",
  "data": {
    "reference": "order-123",
    "paymentLinkId": "...",
    "slug": "...",
    "amount": 5000,
    "currency": "CDF",
    "status": "COMPLETED",
    "environment": "SANDBOX"
  }
}
```

Delivery attempts are logged in **Event Logs → Webhooks** in the dashboard.

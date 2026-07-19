---
title: Developer config API
section: API reference
order: 10
endpoint: getConfig
---

# Developer config API

Discover integration capabilities and sandbox test credentials programmatically. Mainmoney is your acquirer — responses never expose underlying payment processors.

## GET /developers/v1/config

**Auth:** Bearer token (sandbox or live app).

Returns a curated, stable shape — no internal gateway IDs or raw secrets.

```json
{
  "environment": "SANDBOX",
  "app": {
    "name": "My storefront",
    "clientId": "mm_test_...",
    "logoUrl": "https://..."
  },
  "merchant": {
    "displayName": "Acme Shop",
    "countryCode": "CD"
  },
  "payments": {
    "methods": ["card", "momo"],
    "card": { "acquirer": "mainmoney", "mode": "test" },
    "currencies": ["CDF", "USD"]
  },
  "webhooks": { "configured": true },
  "documentation": {
    "testing": "/docs/sandbox/testing",
    "testCards": "/docs/sandbox/test-cards",
    "testMomo": "/docs/sandbox/test-momo",
    "config": "/docs/api/config"
  }
}
```

## GET /developers/v1/sandbox/testing-guide

**Auth:** Bearer token (**sandbox apps only**).

Returns Mainmoney sandbox test cards and MoMo numbers for enabled operators.

## GET /developers/v1/payment-requests

**Auth:** Bearer token.

Paginated list of payment requests for the authenticated app (`page`, `pageSize`).

## Business dashboard proxy

When logged into the business dashboard, the same data is available at:

- `GET /business/developer/config?developerAppId=...`
- `GET /business/developer/sandbox/testing-guide?developerAppId=...`
- `GET /business/developer/payment-requests`

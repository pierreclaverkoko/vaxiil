---
title: Authentication
section: Authentication
order: 10
endpoint: oauthToken
---

# Authentication

Mainmoney developer APIs use **OAuth 2.0 client credentials**.

## Token request

Exchange your app `client_id` and `client_secret` for a short-lived bearer token.

## Response

```json
{
  "data": {
    "access_token": "...",
    "token_type": "Bearer",
    "expires_in": 3600
  }
}
```

Use the token on developer routes:

```
Authorization: Bearer <access_token>
```

Sandbox apps use `mm_test_` client IDs; live apps use `mm_live_`.

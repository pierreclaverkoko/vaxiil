---
title: Getting started
section: Getting started
order: 10
---

# Getting started

Use the Developer dashboard to create a **Sandbox** or **Live** app and obtain `client_id` / `client_secret`. Mainmoney is your acquirer for card and mobile money — you integrate against our API only.

## Base URLs

- API: `https://api.mainmoney.net/api/v2`
- OAuth token: `POST /developers/oauth/token`
- Payment links: `/developers/v1/payment-links`

## Quick flow

1. Create an app in **Apps & Credentials** (optional per-app logo).
2. Call `GET /developers/v1/config` to discover payment methods and sandbox **test mode**.
3. Exchange credentials for a bearer token.
4. `POST /developers/v1/payment-links` with `amount`, `currencyCode`, and required `merchantReference` (optional `redirectUrl`, `title`, `description`, `metadata`).
5. Send payers to the returned `url` (sandbox links show a banner and use Mainmoney test credentials).
6. Verify completion via signed redirect query params, webhooks, or `GET /developers/v1/payment-requests`.

Sandbox activity does not appear in the business ledger — only in the developer dashboard.

See [Authentication](./authentication), [Create a payment link](./payment-links/create-link), and [Sandbox testing](./sandbox/testing).

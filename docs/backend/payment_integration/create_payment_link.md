---
title: Create a payment link
section: Payment links
order: 10
endpoint: createPaymentLink
---

# Create a payment link

Create a hosted checkout link. Payers complete payment on Mainmoney; you receive webhooks and optional redirect callbacks.

## Request body

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Yes | Payment amount in link currency |
| `currencyCode` | Yes | ISO currency code (e.g. `CDF`) |
| `merchantReference` | Yes | Your public payment id (1–128 chars: letters, digits, `.`, `_`, `-`) |
| `redirectUrl` | No | HTTPS URL for signed payer return |
| `title` | No | Checkout title (defaults to business name) |
| `description` | No | Checkout description |
| `metadata` | No | Arbitrary JSON echoed on link responses |
| `brandColor` | No | Hex accent color on the pay page |

Developer links are created as **single-use** (`LIMITED`, `maxUses: 1`) so each `merchantReference` maps to one checkout.

## Response fields

| Field | Description |
| --- | --- |
| `id` | Payment link id |
| `slug` | Public pay slug |
| `url` | Payer checkout URL |
| `merchantReference` | Required. Public payment identifier (status, redirects, webhooks) |
| `title` | Optional checkout title (defaults to business name) |
| `description` | Optional checkout description |
| `metadata` | Optional JSON metadata returned on link responses |

Logo defaults to **app logo**, then business profile logo. Upload a logo when creating the app in the developer dashboard.

Discover capabilities with `GET /developers/v1/config`. Sandbox links use Mainmoney test credentials and do not credit your business wallet.

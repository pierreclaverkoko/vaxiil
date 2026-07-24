# Vaxiil MainMoney payment configuration

This runbook configures MainMoney for the Vaxiil backend. Vendor API details live in the sibling docs in this folder; this page covers Vaxiil-specific env, database, webhooks, and redirects.

User-facing clients must show **Secure payment** / **Pay securely**. Do not expose the MainMoney brand in Flutter or Angular UI.

## 1. Environment variables

Set these in `backend/.env` (see repo root `.env.example`):

| Variable | Purpose |
|----------|---------|
| `MAINMONEY_API_BASE` | API base (default `https://api.mainmoney.net/api/v2`) |
| `MAINMONEY_CLIENT_ID` | OAuth client id (`mm_test_…` sandbox / `mm_live_…` production) |
| `MAINMONEY_CLIENT_SECRET` | OAuth client secret |
| `MAINMONEY_WEBHOOK_SIGNING_SECRET` | HMAC secret for webhook signature verification |
| `PAYMENT_REDIRECT_BASE_URL` | Frontend origin for return after payment (e.g. `http://localhost:4200` or production web URL) |

Also ensure `CORS_ALLOWED_ORIGINS` includes the same frontend origin used for redirects.

Credentials can alternatively be stored on the `PaymentProvider.config` JSON (`client_id`, `client_secret`); env values are the usual path for local/dev.

## 2. Database: activate the provider

Payment links require an **active** `PaymentProvider` with `code='mainmoney'`.

Example (Django shell):

```python
from src.apps.payments.models import PaymentProvider

PaymentProvider.objects.update_or_create(
    code='mainmoney',
    defaults={
        'display_name': 'Secure payment',
        'provider_type': PaymentProvider.ProviderType.OTHER,
        'is_active': True,
        'config': {},  # optional: {'client_id': '...', 'client_secret': '...'}
    },
)
```

Or create/activate the row in Django admin under Payment providers.

## 3. Webhook

Public endpoint:

```text
POST https://<your-api-host>/api/v1/payments/webhooks/mainmoney/
```

- Configure this URL in the MainMoney developer dashboard.
- Use the same signing secret as `MAINMONEY_WEBHOOK_SIGNING_SECRET`.
- Headers expected by Vaxiil: `X-Mainmoney-Signature`, `X-Mainmoney-Event` (see [webhook_events.md](./webhook_events.md)).

On a succeeded **booking** payment, Vaxiil marks the payment transaction succeeded and sets booking **`is_paid`** (status stays **Requested** until the business confirms). On wallet top-up success, store credit is credited.

## 4. Redirect chain

1. Client creates a payment link: `POST /api/v1/payments/bookings/{id}/payment-link/`
2. User completes checkout on the MainMoney hosted page.
3. MainMoney redirects to Vaxiil: `GET|POST /api/v1/payments/redirect/`
4. Vaxiil redirects the browser to `{PAYMENT_REDIRECT_BASE_URL}/payment-return` (with query params for status / reference).

Ensure the Angular (or Flutter web) app serves `/payment-return`.

## 5. Sandbox vs live

- Use `mm_test_` client ids and sandbox base URL for development.
- Test cards / MoMo: [test_cards.md](./test_cards.md), [test_momo.md](./test_momo.md), [sandbox_testing.md](./sandbox_testing.md).
- Switch to live credentials and `mm_live_` only in production.

## 6. Store credit vs card

- **Store credit** (refund wallet): apply optional `wallet_amount` on payment-link create; full cover skips the hosted provider.
- **Card / MoMo**: remaining amount uses the MainMoney payment link.

## 7. Known limits

- Provider refunds via MainMoney are stubbed locally; cancellation credits go to the user’s store credit wallet.
- Stripe env vars are legacy and unused by the payment-link flow.

## 8. Smoke checklist

1. Env vars set; `PaymentProvider(code='mainmoney', is_active=True)` exists.
2. Create a booking → `POST .../payment-link/` → open `url`.
3. Complete sandbox payment → webhook (or redirect verification) succeeds.
4. `GET /api/v1/bookings/{id}/` shows `is_paid: true`, status still `Q` (Requested).
5. Business confirms → status `F`, client receives confirmation email + in-app notification.
6. Optional: top-up via `POST /api/v1/payments/wallet/top-up/` and apply store credit on the next booking.

## Related vendor docs

- [getting_started.md](./getting_started.md)
- [authentification.md](./authentification.md)
- [developer_config.md](./developer_config.md)
- [create_payment_link.md](./create_payment_link.md)
- [redirect_verification.md](./redirect_verification.md)
- [webhook_events.md](./webhook_events.md)

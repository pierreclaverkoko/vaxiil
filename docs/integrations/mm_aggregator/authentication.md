# Authentication

All MM Aggregator merchant requests require a bearer token.

## Token exchange

`POST /api/v1/auth/tokens/exchange/`

```json
{
  "client_id": "your-client-id",
  "secret": "your-secret",
  "expires_in": 3600
}
```

Include the token in every request:

`Authorization: Bearer <access_token>`

## Vaxiil

Credentials: `MM_AGGREGATOR_CLIENT_ID` / `MM_AGGREGATOR_CLIENT_SECRET`, or `PaymentProvider(code='mm_aggregator').config` keys `client_id` / `secret`.

The adapter caches the access token until near expiry (`MmAggregatorPaymentAdapter._get_access_token`).

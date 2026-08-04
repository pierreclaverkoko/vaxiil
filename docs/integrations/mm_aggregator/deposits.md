# Deposits

Create a customer-to-business collection request and monitor its status.

## Endpoint

`POST /api/v1/transactions/deposits/`

## Notes

- Always send a unique `reference` (Vaxiil uses `PaymentTransaction.client_reference`, e.g. `bk_<bookingId>_…` or `wt_<userId>_…`).
- Treat webhook updates as the primary final-status source; use [transaction status check](./transaction_status_check.md) for pull / recovery.
- Persist both internal and provider references from the response.

## Vaxiil

Wired via `MmAggregatorPaymentAdapter.collect()` from:

- `POST /api/v1/payments/bookings/{id}/payment-link/`
- `POST /api/v1/payments/wallet/top-up/`

Clients do not receive a hosted checkout URL — the payer confirms on their phone (STK/USSD) for MoMo collect.

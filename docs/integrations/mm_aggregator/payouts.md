# Payouts

Push funds from merchant wallet to a beneficiary account.

## Endpoint

`POST /api/v1/transactions/payouts/`

Business / merchant-account variants also exist under `/transactions/payouts/business/` (see MM Aggregator source docs).

## Notes

- Ensure merchant wallet has sufficient balance.
- Store `provider_reference` when returned.
- Retry only with idempotency-safe references.
- Status pull: `POST /transactions/status/check/payout/` with the same `reference` body shape as [status check](./transaction_status_check.md).

## Vaxiil

Adapter methods `payout` / `business_payout` exist on `MmAggregatorPaymentAdapter`. Business settlement in the product is still primarily a **staff manual** complete/reject queue; outbound aggregator payout is not auto-wired for every settlement.

# Transaction status check

## Why use this endpoint?

- Webhooks can be delayed, retried, or missed.
- Clients can disconnect before reading the synchronous API response.
- Reconciliation: pull the provider’s current view to align ledgers and support.

The check asks the **provider** for the latest status, **updates the stored transaction** on the aggregator when the provider reports a change, and returns a normalized snapshot.

Use [webhooks](./webhooks.md) for push updates; use **status check** for pull / recovery.

## Endpoint

`POST /api/v1/transactions/status/check/<operation_type>/`

Path parameter **`operation_type`** (lowercase): one of `deposit`, `payout`, `refund`, `remittance`.

## Authentication and scope

- `Authorization: Bearer <access_token>` (see [Authentication](./authentication.md)).
- Merchant application must be allowed the **`TRANSACTION_STATUS_CHECK`** API operation scope.

## Request body

```json
{
  "reference": "your-merchant-reference-or-internal-reference"
}
```

- **`reference`** (required): either **`merchant_reference`** (sent when creating the operation) or **`internal_reference`** (returned on create).

## Successful response

Envelope (`format_response`):

- `success` — `true`
- `response_code` — typically `200`
- `response_data` — object below
- `message` — human-readable summary

### Example `response_data`

```json
{
  "status": "SUCCESS",
  "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "internal_reference": "INT-REF-001",
  "external_reference": "PROVIDER-TXN-XYZ",
  "merchant_reference": "ORDER-12345",
  "provider_reference": "PROVIDER-TXN-XYZ",
  "provider_transaction_id": "",
  "message": "Transaction completed successfully",
  "status_reason": "",
  "amount": "1500.00",
  "currency": "CDF",
  "provider_code": "EXAMPLE_MM",
  "created_at": "2026-05-04T10:00:00+00:00",
  "updated_at": "2026-05-04T10:01:30+00:00",
  "completed_at": "2026-05-04T10:01:30+00:00",
  "status_updated": true,
  "data": {}
}
```

Field notes:

- **`status`**: standardized status after the provider check (`SUCCESS`, pending/processing, failed-style values).
- **`status_updated`**: whether the check changed aggregator local state.
- References: `internal_reference`, `external_reference` / `provider_reference`, `merchant_reference`.

## Errors

| Case | HTTP | Notes |
|------|------|--------|
| Invalid `operation_type` | 400 | Must be deposit/payout/refund/remittance |
| Not found / wrong app | 404 | Unknown or other-merchant reference |
| Provider check failed | 500 | Underlying status query error |
| Missing `reference` | 400 | DRF field validation |

## Vaxiil

- Adapter: `MmAggregatorPaymentAdapter.check_deposit_status(reference=…)` → `POST /transactions/status/check/deposit/`.
- Consumer API: `POST /api/v1/payments/transactions/{client_reference}/refresh/` uses **`deposit`** and `reference = client_reference`, then applies outcome via `apply_payment_outcome` when terminal.

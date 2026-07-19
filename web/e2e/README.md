# Web E2E smoke (Playwright)

## Setup

```bash
yarn install
yarn playwright install chromium
```

## Run

```bash
yarn e2e
```

Starts `ng serve` (unless already running) and runs the smoke spec. HTTP calls to `/api/v1/**` are **mocked** in the test, so a Django backend is not required.

Optional:

- `E2E_BASE_URL` — override the app URL (default `http://127.0.0.1:4200`)

## Coverage

Smoke path: login → discover → service → book (best-effort) → `/bookings/:id/pay` (MainMoney confirm, no external redirect) → business bookings inbox.

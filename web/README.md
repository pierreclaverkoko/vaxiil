# Vaxiil Web (Angular)

Dedicated full web client for Vaxiil (consumer, business management, platform staff).

Progress and conventions: [docs/web/implementation.md](../docs/web/implementation.md).

**Package manager:** Yarn only (`yarn`, not `npm`).

## Prerequisites

- Node.js 24+
- Yarn 1.22.x

## Commands

```bash
yarn install
yarn start          # http://localhost:4200/
yarn build
yarn test           # Vitest (watch)
yarn test:ci        # Vitest once (CI)
yarn lint
yarn format
yarn format:check
```

## Configuration

- API base URL: `src/environments/environment*.ts` → `http://localhost:9091/api/v1/` (matches Flutter `AppConstants.apiBaseUrl`)
- Design tokens: `src/styles/tokens.css` (Verdant Pulse)
- Brand logo: `public/assets/logo.png` (served as `/assets/logo.png`)
- Path alias: `@/*` → `src/app/*`
- Shells: Public (`/onboarding`, `/login`, …), Consumer (`/discover`, …), Business (`/business`), Staff (`/staff`)

## Stack

- Angular 21 (standalone, zoneless, signals)
- SCSS + CSS variables
- Vitest + angular-eslint + Prettier

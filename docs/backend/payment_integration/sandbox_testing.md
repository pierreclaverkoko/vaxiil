---
title: Sandbox testing
section: Sandbox
order: 10
endpoint: testingGuide
---

# Sandbox testing

Sandbox payment links run in **Mainmoney test mode**. No funds settle to your business wallet; webhooks and redirects behave like production.

## Recommended flow

1. Create a **Sandbox** app in the developer dashboard.
2. Call `GET /developers/v1/config` for methods and currencies.
3. Call `GET /developers/v1/sandbox/testing-guide` for current test cards and MoMo numbers.
4. Create a payment link and open the returned `url`.
5. Complete checkout with test credentials or use `simulate-complete` for redirect-only tests.

## Dashboard

The **Testing** page in the developer dashboard mirrors the testing-guide API for your active sandbox app.

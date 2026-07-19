---
title: Test cards
section: Sandbox
order: 20
---

# Test cards (sandbox)

Use **Mainmoney sandbox test cards** at checkout. Card numbers are curated for your integration and may include success, decline, and 3-D Secure scenarios.

## Live list

Call `GET /developers/v1/sandbox/testing-guide` (sandbox apps only) or open the **Testing** page in the developer dashboard for the current card numbers assigned to your app.

## Typical outcomes

| Outcome | Use case |
| --- | --- |
| Success | Happy-path checkout and webhook delivery |
| Declined | Failed payment handling and retry UX |
| 3-D Secure | Strong customer authentication flows when enabled |

Sandbox card payments do not credit your business wallet. Completed payments still trigger developer webhooks.

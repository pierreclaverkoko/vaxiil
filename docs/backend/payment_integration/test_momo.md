---
title: Test MoMo
section: Sandbox
order: 30
---

# Test MoMo (sandbox)

Sandbox payment links accept mobile money through **Mainmoney**. Use operator test MSISDNs approved for your sandbox environment.

## Sample numbers

Fetch operator-specific numbers for your business via `GET /developers/v1/sandbox/testing-guide` or the developer dashboard **Testing** page.

| Operator | Example | Notes |
| --- | --- | --- |
| Airtel Money DRC | `+243970000001` | Must match an enabled MoMo gateway |
| Orange Money DRC | `+243890000001` | Sandbox only |
| Vodacom M-Pesa DRC | `+243810000001` | Sandbox only — no wallet credit |

## Tips

- Phone numbers must match an enabled MoMo gateway for your business currency.
- Completed sandbox MoMo payments trigger developer webhooks but do not credit the business wallet.
- QR (in-app scan) is disabled on sandbox links.

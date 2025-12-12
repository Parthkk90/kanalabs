# Payments, On/Off Ramp, and Compliance Plan

## 1. UPI On-Ramp Strategy
- **Primary Providers**: Stripe (via Petra Wallet integration), Banxa, Mesh, Transak. All expose UPI collect + net banking rails.
- **Flow**:
  1. User enters amount → API requests payment link from preferred provider.
  2. Provider handles KYC (PAN + Aadhaar) and risk checks; result posted to our webhook.
  3. On success, INR ledger credited; funds available for pack execution.
- **Selection Logic**: Route to provider with best fee + uptime in past 5 min; fallback sequentially.
- **Settlement Window**: Expect T+0 during business hours, T+1 otherwise. Maintain buffer float to allow instant investing while awaiting settlement.

## 2. Off-Ramp / Withdrawals
- Support USDC → INR conversions via same partners; require Tier-2 KYC.
- Enforce min ₹2,000 withdrawal; apply 1% fee + network costs.
- Provide 24h cooling period for new beneficiaries.

## 3. Compliance & KYC
- **Tier 1**: Aadhaar OTP + PAN validation; limits ₹50k/month.
- **Tier 2**: Bank statement + selfie; unlocks ₹5L/month and withdrawals.
- **Record Keeping**: Store signed KYC hashes in encrypted vault; purge raw docs per RBI guidelines.
- Integrate AML screening (Dow Jones or similar) before enabling recurring SIPs.

## 4. Tax + Accounting Hooks
- Calculate GST on service fee component; remit monthly.
- Track TDS for any yield payouts >₹50k.
- Provide annual AIS-compatible statement (JSON + PDF) summarizing INR inflows/outflows and crypto holdings.

## 5. Provider Integration Notes
| Provider | API Docs | Key Requirements |
| --- | --- | --- |
| Stripe (Petra route) | `https://outposts.io/article/petra-wallet-integrates-on-ramp...` | Need Petra SDK access + Stripe India account; supports saved VPA |
| Banxa | `https://banxa.com/developers` | Requires wallet whitelisting; settlement in USDC → convert to INR |
| Mesh | `https://meshconnect.com/docs` | Offers account aggregation; leverage for bank verification |
| Transak | `https://transak.com/docs` | Fastest UPI support; use as default for <₹25k |

## 6. Operational Controls
- Monitor provider SLA dashboards; auto-disable ones breaching 2% failure in rolling hour.
- Webhooks verified via HMAC; replay protection through nonce store.
- Maintain compliance audit trail: payment request, provider response, ledger update, swap intent.

## 7. Open Items
1. Confirm RBI/SEBI stance on pooled crypto investments and categorize product (likely “technology platform” + distributor).
2. Evaluate need for NBFC partner to hold INR floats beyond 24 hours.
3. Define dispute resolution + chargeback SOP with each provider.

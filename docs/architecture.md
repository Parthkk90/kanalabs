# Chota Crypto — System Architecture

> For the execution phases and sprint plan, see the project roadmap in [docs/roadmap.md](./roadmap.md).

## 1. Vision Snapshot
- **Product**: One-click INR → curated multi-chain crypto packs for mass retail in India.
- **Differentiator**: Mutual-fund UX powered by ZyraLabs (Kana) infra: cross-chain routing, smart wallets, gas sponsorship, and keyless onboarding.
- **North Star Metric**: Weekly recurring buys executed per active user.

## 2. Component Map
| Layer | Responsibilities | Vendor / Build Notes |
| --- | --- | --- |
| Client Apps (mobile + web) | Pack discovery, UPI collect flow, confirmation, portfolio view | Built custom; reuse Kana widget aesthetics for swap confirmations |
| API Gateway | Auth, session orchestration, webhook intake, rate limiting, pack catalog | Custom service; deploy on managed Kubernetes/App Service |
| Pack Orchestrator | Allocation math, swap intents, routing requests, compliance logging | Runs on serverless worker (Azure Functions) for elasticity |
| Kana/Xyra Aggregator SDK | Cross-chain swaps, bridge selection, liquidity aggregation | `https://docs.kanalabs.io/cross-chain-swaps/amm-dex-aggregator`
| Kana Paymaster + Mirai Smart Wallet | Keyless onboarding, AA accounts, sponsored gas | `https://docs.kanalabs.io/smart-wallet-sdk/mirai-sdk-the-omni-chain-smart-wallet`
| Fiat On/Off Ramp | INR UPI acceptance, settlement, compliance KYC | Stripe/Banxa/Mesh/Transak via Petra Wallet partnership (`https://outposts.io/article/petra-wallet-integrates-on-ramp...`)
| Data Warehouse | Order events, compliance feeds, retention metrics | Azure Synapse or BigQuery; CDC from operational DB

## 3. High-Level Flow
1. **Onboarding**: User signs in with phone/email → Mirai SDK mints smart account + links Aadhaar-lite KYC.
2. **Load INR**: UPI collect request triggered via partner on-ramp → webhook confirms settlement → ledger marks spending balance.
3. **Pack Selection**: Client fetches pack metadata (tokens, weights) from API.
4. **Intent Build**: User picks amount; Pack Orchestrator calculates per-asset allocation and requests optimal routes via Kana Aggregator SDK.
5. **Execution**: Orchestrator signs swap bundle, Paymaster sponsors gas (where available), Kana auto-routes across chains/bridges.
6. **Settlement**: Resulting tokens deposited into user smart account vaults; holdings recorded per pack + chain.
7. **Receipts**: User sees confirmation, scheduled DCA reminder, downloadable tax packet.

## 4. Deployment Topology
```
[Client Apps]
    |
[AAD B2C / Custom Auth]
    |
[API Gateway]----[Admin Console]
    |
[Pack Orchestrator Functions]---(calls)---[Kana Aggregator SDK]
    |                                             |
[Event Bus]                                  [Kana Paymaster]
    |
[Data Warehouse] <--- [Operational DB] ---> [Compliance/KYC]
```

## 5. Data Contracts
- **Pack Definition**: `pack_id`, `name`, `theme`, `token_allocations[]`, `rebalancing_rules`, `risk_band`, `disclosure_md`.
- **Investment Order**: `order_id`, `user_id`, `pack_id`, `amount_in_inr`, `fx_rate`, `swap_routes[]`, `status`, `settled_tokens[]`.
- **UPI Ledger Entry**: `txn_id`, `vpa`, `reference_id`, `status`, `net_amount`, `source_provider`.

## 6. Reliability & Controls
- Leverage Kana route simulation before broadcast to detect MEV or liquidity gaps.
- Shadow price oracle per token to ensure deviations <1.5% vs. benchmark; auto-retry or alert if exceeded.
- Webhook signature validation for on-ramp callbacks.
- Event-sourced ledger for INR balance + crypto holdings to simplify audits.

## 7. Compliance & Risk Hooks
- Tiered KYC: up to ₹50k monthly with Aadhaar OTP, higher tiers require PAN + bank proof.
- FATF Travel Rule readiness by logging destination smart accounts per swap.
- GST and TDS tracking for service fees.

## 8. Open Questions
1. Confirm Kana SDK SLA + hosting requirements in India region.
2. Determine if Paymaster can cover non-Aptos chains or if fallback gas wallet needed.
3. Decide custodial stance for user wallets (export keys vs. pure smart-account custody).

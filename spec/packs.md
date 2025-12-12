# Pack Catalog Specification

## 1. Data Model
```json
{
  "pack_id": "string",
  "display_name": "string",
  "tagline": "string",
  "base_currency": "INR",
  "min_invest_inr": 500,
  "allocation_bps": [
    {
      "token_symbol": "string",
      "network": "APTOS|SOL|ETH|BSC|POLYGON|BASE",
      "weight_bps": 0,
      "routing_hint": "JUPITER|1INCH|KANAAUTO"
    }
  ],
  "rebalance": {
    "cadence_days": 30,
    "threshold_bps": 1500,
    "execution_mode": "auto|manual"
  },
  "dca": {
    "supported": true,
    "frequency_options": ["weekly", "monthly"],
    "min_sip_inr": 100
  },
  "disclosures_md": "path/to/disclosure.md",
  "risk_score": 1,
  "benchmark": "Coingecko list / custom index",
  "kyc_tier_required": 1
}
```

## 2. Initial Packs
### AI Coins Pack
- **Thesis**: Exposure to AI-aligned infrastructure and compute tokens.
- **Tokens**: `FET` (ETH), `RNDR` (ETH), `TAO` (ETH), `AKT` (COSMOS via wrapped route).
- **Weights**: 30/30/25/15.
- **Routing**: ETH mainnet via Kana Aggregator with 1inch + OKX liquidity; AKT through Axelar bridge → wrapped ERC20.
- **Risk**: Score 4/5; gating at Tier-2 KYC.

### Bluechip Pack
- **Thesis**: Large-cap defensive basket for first-time investors.
- **Tokens**: `BTC` (wBTC on ETH), `ETH`, `APT`, `SOL`.
- **Weights**: 35/35/15/15.
- **Routing**: BTC/ETH via Kana aggregator; SOL via Kana + Jupiter; APT via Paymaster-enabled swap.
- **Risk**: Score 2/5; Tier-1 KYC.

### Solana Momentum Pack
- **Thesis**: Capture Solana ecosystem upside without DIY staking.
- **Tokens**: `SOL`, `JTO`, `JUP`, `PYTH`.
- **Weights**: 40/20/20/20.
- **Routing**: All on Solana using Kana auto-route → Jupiter/Orca pools.
- **Risk**: Score 3/5; Tier-2 KYC.

### ETH L2 Scaling Pack
- **Thesis**: Bet on rollup adoption and sequencer fee accrual.
- **Tokens**: `OP`, `ARB`, `MANTA`, `STRK` (on Starknet via bridge).
- **Weights**: 30/30/20/20.
- **Routing**: ETH mainnet to destination L2 using Kana bridge intent; fallback to LayerZero.
- **Risk**: Score 3/5; Tier-2 KYC.

## 3. Allocation Logic
1. Convert INR input to USDC via on-ramp partner FX.
2. Apply `allocation_bps` to derive per-token notional.
3. For each token:
   - Query Kana route simulator with `slippage_limit_bps = 75`.
   - Reserve gas if Paymaster unavailable (EVM fallback hot wallet).
   - Execute swap + bridge; verify fills >= 99% of expected output.
4. Aggregate fills back into pack ledger; emit event for analytics.

## 4. Rebalancing Rules
- Auto-run monthly cron; skip if drift < threshold.
- During rebalance, respect user tax lots by swapping within smart account, minimizing realized gains.
- Provide pre-trade notice and allow opt-out per regulatory guidance.

## 5. SIP/DCA Support
- Users authorize recurring UPI autopay mandate.
- Scheduler triggers Pack Orchestrator; same allocation as lump sum but with `max_slippage_bps = 50` due to smaller clip.
- Failed SIP attempts auto-retry ×3 before notifying user.

## 6. Telemetry
- Track per-pack AUM, churn, SIP retention, and execution cost (bps) to optimize fees and marketing narratives.

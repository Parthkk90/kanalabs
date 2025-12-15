# Blockchain Architecture — Chota Crypto

## 1. Overview
The blockchain layer handles multi-chain asset custody, pack allocation execution, cross-chain routing, and transparent on-chain operations. This architecture leverages Kana/Zyra Labs infrastructure while maintaining user sovereignty through smart account abstraction.

## 2. Core Blockchain Components

### 2.1 Smart Account Layer (Mirai SDK)
- **Purpose**: Keyless, gasless user accounts across chains
- **Chains**: EVM (Ethereum, Base, Polygon, BSC), Aptos, Sui, Solana
- **Features**:
  - Email/phone-based account recovery
  - Multi-sig capabilities for high-value accounts
  - Session keys for automated SIP execution
  - Paymaster integration for sponsored transactions

### 2.2 Pack Vault Contracts
- **Purpose**: Manage pooled user investments per pack
- **Key Functions**:
  - `deposit(packId, amount, userAddress)`: Record user investment
  - `executeRebalance(packId, newAllocations)`: Admin-triggered rebalancing
  - `withdraw(packId, amount, userAddress)`: User exit with proportional shares
  - `getPackComposition(packId)`: Return current token holdings
- **Deployment**: Multi-chain (primary on Base L2 for low fees, mirrored states via LayerZero)

### 2.3 Cross-Chain Router Integration (Kana Aggregator SDK)
- **Purpose**: Execute optimal swaps and bridges across 9+ chains
- **Integration Points**:
  - Route simulation API: Pre-flight checks before execution
  - Intent-based swaps: Submit destination token requirements
  - Bridge aggregation: Auto-select LayerZero, Wormhole, Axelar, Circle CCTP
- **Execution Flow**:
  1. Backend builds swap intent from pack allocation
  2. Query Kana for optimal route (liquidity, fees, time)
  3. Sign and broadcast transaction bundle
  4. Monitor completion via Kana webhook or polling

### 2.4 Oracle & Price Feeds
- **Purpose**: Validate execution prices and detect anomalies
- **Providers**:
  - Primary: Chainlink (ETH, BTC, major alts)
  - Secondary: Pyth Network (real-time for Solana ecosystem)
  - Fallback: Kana internal pricing (aggregated from DEX pools)
- **Deviation Alerts**: Trigger if execution price differs >1.5% from oracle

### 2.5 Paymaster Service (Kana)
- **Purpose**: Sponsor gas for Aptos/Supra transactions
- **API Integration**:
  - `/sponsorGas`: Request gas sponsorship for user transactions
  - Whitelist user smart accounts based on KYC tier
  - Monitor daily spend limits to prevent abuse
- **Fallback**: Maintain hot wallets on EVM chains for non-sponsored txs

## 3. Multi-Chain Strategy

### Supported Chains (V1)
| Chain | Use Case | Pack Tokens | Gas Strategy |
|-------|----------|-------------|--------------|
| Ethereum Mainnet | Bluechip, AI Coins (wBTC, ETH, FET, RNDR) | Vault on Base, bridge via Circle CCTP | User-paid or batched admin txs |
| Base L2 | Primary vault layer, low-fee operations | All packs | Sponsored via Coinbase Commerce credits |
| Solana | Solana Momentum Pack (SOL, JTO, JUP, PYTH) | Native Jupiter integration | Paymaster for small SIPs |
| Aptos | APT holdings, Mirai smart accounts | Kana Paymaster | Fully sponsored |
| Polygon | Backup vault, DeFi yield integrations (future) | TBD | User-paid |

### Chain Selection Logic
- Default to Base for vault operations (cheapest gas)
- Route pack-specific tokens on native chains (SOL on Solana, APT on Aptos)
- Bridge only when necessary; prefer single-chain execution via wrapped assets

## 4. Smart Contract Design

### 4.1 PackVault.sol (EVM - Base)
```solidity
// Simplified interface
contract PackVault {
    struct Pack {
        string packId;
        uint256 totalValueLocked;
        mapping(address => uint256) userShares;
        TokenAllocation[] allocations;
    }
    
    struct TokenAllocation {
        address token;
        uint256 weightBps; // basis points (10000 = 100%)
    }
    
    // Core functions
    function deposit(string memory packId, uint256 amount) external;
    function withdraw(string memory packId, uint256 shares) external;
    function rebalance(string memory packId, TokenAllocation[] memory newAllocations) external onlyAdmin;
    function getPackValue(string memory packId) external view returns (uint256);
}
```

### 4.2 Access Control
- **Admin Role**: Managed by multi-sig (Gnosis Safe) for rebalance execution
- **Operator Role**: Backend service address for deposit/withdraw coordination
- **User Role**: Any verified smart account can deposit/withdraw

### 4.3 Security Features
- **Pause Mechanism**: Emergency stop for deposits/withdrawals
- **Rate Limiting**: Max daily volume per user/pack to prevent flash attacks
- **Time-locked Upgrades**: 48-hour delay for contract logic changes
- **Audit Trail**: Emit events for all state changes (deposits, withdrawals, rebalances)

## 5. Transaction Flow Examples

### Example 1: User Invests ₹5000 in Bluechip Pack
1. User confirms investment in mobile app
2. Backend collects INR via UPI → credits internal ledger
3. Backend calls Kana on-ramp partner API to convert INR → USDC on Base
4. Backend calculates Bluechip allocation: 35% BTC, 35% ETH, 15% APT, 15% SOL
5. For each token:
   - Query Kana Aggregator for route (USDC → wBTC on Base, USDC → ETH on Base, USDC → bridged APT, USDC → bridged SOL)
   - Execute swap intents via Kana SDK
6. Deposit resulting tokens into PackVault contract (Base chain) with user smart account address
7. Emit `PackDeposit` event; backend updates user portfolio

### Example 2: Monthly Rebalance for AI Coins Pack
1. Scheduled cron (first Sunday of month) triggers rebalance check
2. Backend queries current pack composition from PackVault
3. Compare actual weights vs target (FET 30%, RNDR 30%, TAO 25%, AKT 15%)
4. If drift >15% threshold:
   - Calculate swap sizes to restore balance
   - Query Kana for optimal routes
   - Submit rebalance transaction to PackVault with new allocations
   - PackVault executes internal swaps via Kana Router
5. Emit `PackRebalanced` event with before/after snapshot

### Example 3: User Withdraws ₹10,000 from Solana Momentum Pack
1. User initiates withdrawal in app; backend validates Tier-2 KYC and cooling period
2. Calculate user share of pack (e.g., 0.05% of total)
3. Redeem proportional tokens from PackVault:
   - 0.05% of SOL balance → user smart account
   - 0.05% of JTO, JUP, PYTH → user smart account
4. Backend offers two options:
   - **Keep crypto**: Transfer to user's external wallet
   - **Convert to INR**: Swap tokens → USDC via Kana, then off-ramp to bank via Banxa/Transak
5. Record withdrawal event; update ledger

## 6. Integration with Kana/Zyra Labs

### SDK Endpoints Used
- **Web3 Aggregator SDK**: Multi-chain swap routing
  - `POST /v1/route/simulate`: Pre-flight route validation
  - `POST /v1/route/execute`: Execute cross-chain swap intent
- **Mirai Smart Wallet SDK**: User account management
  - `createWallet(email)`: Generate keyless account
  - `getWalletAddress(userId, chainId)`: Retrieve chain-specific address
- **Paymaster API**: Gas sponsorship
  - `POST /paymaster/sponsorGas`: Request gas coverage for Aptos txs
  - `GET /paymaster/balance`: Check sponsor account balance

### Webhook Handlers
- **Route Completion**: Receive notification when cross-chain swap settles
- **Gas Sponsorship Failure**: Fallback to user-paid gas or retry

## 7. On-Chain Data & Indexing

### Events to Index
- `PackDeposit(address user, string packId, uint256 shares, uint256 timestamp)`
- `PackWithdraw(address user, string packId, uint256 shares, uint256 timestamp)`
- `PackRebalanced(string packId, TokenAllocation[] before, TokenAllocation[] after, uint256 timestamp)`
- `EmergencyPause(string reason, uint256 timestamp)`

### Indexer Strategy
- Use The Graph for Base L2 contract events
- Solana: Helius webhooks for program logs
- Aptos: Indexer API for Move module events
- Store indexed data in warehouse for analytics (pack AUM, user activity, rebalance frequency)

## 8. Security & Compliance

### Smart Contract Audits
- Pre-mainnet: Engage Consensys Diligence or OpenZeppelin for vault contract audit
- Post-deploy: Bug bounty on Immunefi (up to $50k for critical vulnerabilities)

### Custody Model
- User assets remain in smart accounts (non-custodial)
- Pack Vault contracts are transparent; users can exit anytime
- Admin keys held in 3-of-5 multi-sig; signers geographically distributed

### Regulatory Hooks
- All on-chain deposits/withdrawals logged with KYC tier metadata (off-chain)
- Support AML address screening via Chainalysis API before deposit acceptance
- Provide on-chain proof-of-reserve via Chainlink Proof of Reserve oracle

## 9. Development Phases

### Phase 1: Testnet Deployment (Weeks 1-3)
- Deploy PackVault contracts on Base Sepolia and Polygon Mumbai
- Integrate Kana Aggregator SDK in sandbox mode
- Test deposit/withdraw flows with testnet faucet tokens
- Set up event indexing on testnet

### Phase 2: Mainnet Launch (Weeks 4-6)
- Audit and deploy PackVault to Base mainnet
- Configure multi-sig admin (Gnosis Safe)
- Whitelist Kana Router addresses for swap execution
- Enable Paymaster for Aptos smart accounts

### Phase 3: Cross-Chain Expansion (Weeks 7-10)
- Add Solana pack support via Jupiter integration
- Deploy mirrored state contracts on Polygon for DeFi yield features
- Implement LayerZero messaging for pack state synchronization

## 10. Open Technical Questions
1. **Gas Optimization**: Should we batch multiple user deposits into single vault transaction? (Trade-off: latency vs cost)
2. **Rebalance Governance**: Allow pack creator to vote on rebalance params, or keep fully automated?
3. **MEV Protection**: Integrate Flashbots RPC or private mempools for large rebalances?
4. **Upgradability**: Use UUPS proxy pattern or keep vaults immutable with migration logic?

# Kana/Zyra Labs SDK Integration Guide

## 1. Overview
This document details integration with Kana Labs (now Zyra Labs) infrastructure for cross-chain swaps, smart wallets, and gas sponsorship.

## 2. SDK Components

### 2.1 Web3 Aggregator SDK (Cross-Chain Swaps)
**Purpose**: Execute optimal multi-chain token swaps and bridges  
**Documentation**: https://docs.kanalabs.io/web3-aggregator-sdk/web3-aggregator-sdk

#### Installation
```bash
npm install @kanalabs/aggregator-sdk
# or
yarn add @kanalabs/aggregator-sdk
```

#### Basic Usage
```typescript
import { KanaAggregator } from '@kanalabs/aggregator-sdk';

const aggregator = new KanaAggregator({
  apiKey: process.env.KANA_API_KEY,
  environment: 'production' // or 'sandbox'
});

// Get optimal route
const route = await aggregator.getRoute({
  fromToken: {
    address: '0xUSDC_ADDRESS',
    chainId: 8453, // Base
    amount: '1000000000' // 1000 USDC (6 decimals)
  },
  toToken: {
    address: '0xWBTC_ADDRESS',
    chainId: 8453,
  },
  slippage: 0.5, // 0.5%
  userAddress: '0xUSER_WALLET'
});

// Execute swap
const txHash = await aggregator.executeSwap({
  route: route,
  userSigner: signer // ethers.js signer
});
```

#### Route Simulation (Pre-flight Check)
```typescript
// Validate route before execution
const simulation = await aggregator.simulateRoute({
  routeId: route.id,
  validatePrices: true,
  checkLiquidity: true
});

if (!simulation.success) {
  console.error('Route failed simulation:', simulation.errors);
  throw new Error('Cannot execute swap');
}

// Check price impact
if (simulation.priceImpact > 2.0) {
  console.warn('High price impact detected:', simulation.priceImpact);
  // Implement user confirmation flow
}
```

#### Multi-Chain Routing
```typescript
// USDC on Base → SOL on Solana (cross-chain)
const crossChainRoute = await aggregator.getRoute({
  fromToken: {
    address: '0xUSDC_ADDRESS',
    chainId: 8453, // Base
    amount: '5000000000' // 5000 USDC
  },
  toToken: {
    address: 'So11111111111111111111111111111111111111112', // SOL
    chainId: 900, // Solana (Kana internal chain ID)
  },
  slippage: 1.0,
  userAddress: '0xUSER_WALLET',
  bridgePreference: 'fastest' // or 'cheapest' or 'safest'
});

// Kana auto-selects bridge (LayerZero, Wormhole, Axelar, Circle CCTP)
console.log('Selected bridge:', crossChainRoute.bridge);
console.log('Estimated time:', crossChainRoute.estimatedTime); // in seconds
console.log('Total fees:', crossChainRoute.totalFees); // in USD
```

---

### 2.2 Mirai Smart Wallet SDK
**Purpose**: Keyless, gasless user accounts with account abstraction  
**Documentation**: https://docs.kanalabs.io/smart-wallet-sdk/mirai-sdk-the-omni-chain-smart-wallet

#### Installation
```bash
npm install @kanalabs/mirai-sdk
```

#### Create Smart Account
```typescript
import { MiraiSDK } from '@kanalabs/mirai-sdk';

const mirai = new MiraiSDK({
  apiKey: process.env.KANA_API_KEY,
  chains: [8453, 137, 1, 900], // Base, Polygon, Ethereum, Solana
});

// Create keyless account with email
const account = await mirai.createAccount({
  email: 'user@example.com',
  // Or use phone: '+919876543210'
});

console.log('Smart account addresses:', account.addresses);
// {
//   8453: '0xABC...', // Base
//   137: '0xDEF...',  // Polygon
//   1: '0xGHI...',    // Ethereum
//   900: 'SOLANA_ADDRESS'
// }
```

#### Session Keys for Automated SIP
```typescript
// Grant backend service permission for recurring deposits
const sessionKey = await mirai.createSessionKey({
  accountId: account.id,
  permissions: {
    allowedContracts: ['0xPACK_VAULT_ADDRESS'],
    allowedFunctions: ['deposit(string,uint256)'],
    maxAmount: '10000000000', // 10k USDC max per tx
    expiryTimestamp: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60 // 30 days
  }
});

// Backend can now execute deposits without user signature
const backendSigner = new ethers.Wallet(sessionKey.privateKey);
```

#### Gasless Transactions (EVM)
```typescript
// Send transaction with gas sponsorship
const tx = await mirai.sendTransaction({
  accountId: account.id,
  chainId: 8453,
  to: '0xPACK_VAULT_ADDRESS',
  data: depositCalldata,
  sponsored: true, // Request Paymaster sponsorship
});

console.log('Transaction hash:', tx.hash);
console.log('Gas sponsored:', tx.gasSponsored); // true if Paymaster covered
```

---

### 2.3 Kana Paymaster Service
**Purpose**: Sponsor gas fees for Aptos and Supra transactions  
**Documentation**: https://docs.kanalabs.io/paymaster-service/kana-paymaster-for-aptos-and-supra

#### API Endpoints
```typescript
const PAYMASTER_BASE_URL = 'https://paymaster.kanalabs.io/v1';

// Deposit sponsor funds
async function depositSponsorFunds(amount: string) {
  const response = await fetch(`${PAYMASTER_BASE_URL}/deposit`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.KANA_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      network: 'aptos-mainnet',
      amount: amount, // in APT
    })
  });
  return response.json();
}

// Whitelist user addresses
async function whitelistUser(userAddress: string) {
  const response = await fetch(`${PAYMASTER_BASE_URL}/whitelist`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.KANA_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      network: 'aptos-mainnet',
      addresses: [userAddress],
      dailyLimit: '100000000', // 1 APT daily per user
    })
  });
  return response.json();
}

// Sponsor gas for transaction
async function sponsorGas(txPayload: any, userAddress: string) {
  const response = await fetch(`${PAYMASTER_BASE_URL}/sponsorGas`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.KANA_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      network: 'aptos-mainnet',
      sender: userAddress,
      payload: txPayload,
    })
  });
  
  const data = await response.json();
  // Returns co-signed transaction ready to broadcast
  return data.signedTransaction;
}
```

#### Aptos Integration
```typescript
import { AptosClient, AptosAccount } from 'aptos';

const client = new AptosClient('https://fullnode.mainnet.aptoslabs.com/v1');

// Build deposit transaction
const payload = {
  type: 'entry_function_payload',
  function: '0xCHOTA_CRYPTO::pack_vault::deposit',
  type_arguments: [],
  arguments: ['bluechip_pack', '5000000000'] // 5000 USDC
};

const userAccount = new AptosAccount(); // User's Aptos account

// Request Paymaster sponsorship
const sponsoredTx = await sponsorGas(payload, userAccount.address().hex());

// Broadcast transaction
const txResult = await client.submitSignedBCSTransaction(sponsoredTx);
console.log('Gasless transaction:', txResult.hash);
```

---

### 2.4 Kana Widget (Optional: In-App Swap UI)
**Purpose**: Embeddable swap interface for quick liquidity access  
**Documentation**: https://docs.kanalabs.io/integrate-kana-widget/kana-widget

#### Integration
```html
<!-- React Native WebView or Web App -->
<iframe
  src="https://widget.kanalabs.io/swap?
    fromToken=USDC&
    toToken=ETH&
    theme=dark&
    apiKey=YOUR_API_KEY&
    walletAddress=0xUSER_WALLET"
  width="400"
  height="600"
  frameborder="0"
></iframe>
```

#### Customization
```typescript
const widgetUrl = new URL('https://widget.kanalabs.io/swap');
widgetUrl.searchParams.append('theme', 'custom');
widgetUrl.searchParams.append('primaryColor', '#F9B233'); // Chota Crypto saffron
widgetUrl.searchParams.append('backgroundColor', '#0A1A2F');
widgetUrl.searchParams.append('feeRecipient', '0xCHOTA_CRYPTO_FEE_WALLET');
widgetUrl.searchParams.append('feePercentage', '0.1'); // 0.1% platform fee

// Embed in React Native
import { WebView } from 'react-native-webview';

<WebView
  source={{ uri: widgetUrl.toString() }}
  onMessage={(event) => {
    const data = JSON.parse(event.nativeEvent.data);
    if (data.event === 'swap_completed') {
      console.log('Swap hash:', data.txHash);
      // Update user portfolio
    }
  }}
/>
```

---

## 3. Backend Integration Architecture

### 3.1 Pack Orchestrator Service
```typescript
import { KanaAggregator } from '@kanalabs/aggregator-sdk';
import { MiraiSDK } from '@kanalabs/mirai-sdk';

class PackOrchestrator {
  private aggregator: KanaAggregator;
  private mirai: MiraiSDK;
  
  constructor() {
    this.aggregator = new KanaAggregator({ 
      apiKey: process.env.KANA_API_KEY 
    });
    this.mirai = new MiraiSDK({ 
      apiKey: process.env.KANA_API_KEY 
    });
  }
  
  async executePack Investment(params: {
    userId: string;
    packId: string;
    usdcAmount: string;
    allocations: TokenAllocation[];
  }) {
    // 1. Get user smart account
    const userAccount = await this.mirai.getAccount(params.userId);
    
    // 2. For each token in pack allocation
    const swapPromises = params.allocations.map(async (allocation) => {
      const amountForToken = BigInt(params.usdcAmount) * BigInt(allocation.weightBps) / 10000n;
      
      // 3. Get route from USDC to target token
      const route = await this.aggregator.getRoute({
        fromToken: {
          address: USDC_ADDRESS,
          chainId: 8453,
          amount: amountForToken.toString()
        },
        toToken: {
          address: allocation.tokenAddress,
          chainId: allocation.chainId,
        },
        slippage: 0.75, // 0.75% max slippage
        userAddress: userAccount.addresses[8453]
      });
      
      // 4. Simulate before executing
      const sim = await this.aggregator.simulateRoute({ routeId: route.id });
      if (!sim.success) {
        throw new Error(`Route failed for ${allocation.symbol}: ${sim.errors}`);
      }
      
      // 5. Execute swap
      return this.aggregator.executeSwap({ route });
    });
    
    // Execute all swaps in parallel
    const results = await Promise.allSettled(swapPromises);
    
    // 6. Record results in database
    for (const [index, result] of results.entries()) {
      if (result.status === 'fulfilled') {
        await this.recordSwap({
          userId: params.userId,
          packId: params.packId,
          token: params.allocations[index].symbol,
          txHash: result.value.hash,
          status: 'completed'
        });
      } else {
        console.error('Swap failed:', result.reason);
        // Trigger retry logic or alert
      }
    }
    
    return {
      successful: results.filter(r => r.status === 'fulfilled').length,
      failed: results.filter(r => r.status === 'rejected').length
    };
  }
}
```

### 3.2 Webhook Handlers
```typescript
import express from 'express';
import crypto from 'crypto';

const app = express();

// Kana webhook endpoint
app.post('/webhooks/kana/swap-completed', express.json(), (req, res) => {
  // Verify webhook signature
  const signature = req.headers['x-kana-signature'];
  const payload = JSON.stringify(req.body);
  const expectedSig = crypto
    .createHmac('sha256', process.env.KANA_WEBHOOK_SECRET)
    .update(payload)
    .digest('hex');
  
  if (signature !== expectedSig) {
    return res.status(401).send('Invalid signature');
  }
  
  const event = req.body;
  
  switch (event.type) {
    case 'swap.completed':
      handleSwapCompleted(event.data);
      break;
    case 'swap.failed':
      handleSwapFailed(event.data);
      break;
    case 'bridge.pending':
      handleBridgePending(event.data);
      break;
    case 'bridge.completed':
      handleBridgeCompleted(event.data);
      break;
  }
  
  res.status(200).send('OK');
});

async function handleSwapCompleted(data: any) {
  // Update order status in database
  await db.orders.update({
    where: { kanaRouteId: data.routeId },
    data: {
      status: 'completed',
      txHash: data.txHash,
      outputAmount: data.amountOut,
      completedAt: new Date()
    }
  });
  
  // Notify user
  await notificationService.send({
    userId: data.userId,
    type: 'investment_completed',
    message: `Your ${data.packName} investment is complete!`
  });
}
```

---

## 4. Error Handling & Fallbacks

### 4.1 Route Failures
```typescript
async function executeSwapWithFallback(params: SwapParams) {
  try {
    // Try Kana primary route
    const route = await aggregator.getRoute(params);
    return await aggregator.executeSwap({ route });
  } catch (error) {
    console.error('Kana route failed:', error);
    
    // Fallback: Try direct 1inch or 0x API
    const fallbackRoute = await get1inchRoute(params);
    return await execute1inchSwap(fallbackRoute);
  }
}
```

### 4.2 Paymaster Unavailable
```typescript
async function depositWithGasFallback(params: DepositParams) {
  const tx = await buildDepositTx(params);
  
  try {
    // Try Paymaster sponsorship
    const sponsored = await sponsorGas(tx, params.userAddress);
    return await broadcast(sponsored);
  } catch (error) {
    console.warn('Paymaster unavailable, using hot wallet');
    
    // Fallback: Pay gas from platform hot wallet
    const hotWallet = new ethers.Wallet(process.env.HOT_WALLET_KEY);
    return await hotWallet.sendTransaction(tx);
  }
}
```

---

## 5. Testing

### 5.1 Sandbox Environment
```typescript
// Use Kana sandbox for testing
const aggregator = new KanaAggregator({
  apiKey: process.env.KANA_SANDBOX_API_KEY,
  environment: 'sandbox'
});

// Sandbox uses testnet addresses and fake liquidity
const testRoute = await aggregator.getRoute({
  fromToken: { address: USDC_SEPOLIA, chainId: 84532, amount: '1000000' },
  toToken: { address: WETH_SEPOLIA, chainId: 84532 },
  userAddress: TEST_WALLET
});
```

### 5.2 Integration Tests
```typescript
describe('Pack Orchestrator + Kana Integration', () => {
  it('should execute Bluechip pack investment', async () => {
    const result = await orchestrator.executePackInvestment({
      userId: 'test_user',
      packId: 'bluechip',
      usdcAmount: '5000000000', // 5k USDC
      allocations: BLUECHIP_ALLOCATIONS
    });
    
    expect(result.successful).toBe(4); // BTC, ETH, APT, SOL
    expect(result.failed).toBe(0);
  });
});
```

---

## 6. Monitoring & Observability

### 6.1 Key Metrics
- **Route success rate**: % of Kana routes that execute successfully
- **Average execution time**: Time from route request to settlement
- **Slippage distribution**: Actual slippage vs. expected
- **Paymaster utilization**: % of txs sponsored vs. self-paid

### 6.2 Alerts
```typescript
// Alert if route failures exceed threshold
if (routeFailureRate > 0.05) { // 5%
  alertOps({
    severity: 'high',
    message: 'Kana route failure rate exceeds 5%',
    metric: routeFailureRate
  });
}

// Alert if Paymaster balance low
if (paymasterBalance < MIN_BALANCE) {
  alertFinance({
    severity: 'medium',
    message: 'Paymaster APT balance below threshold',
    balance: paymasterBalance
  });
}
```

---

## 7. Rate Limits & Quotas

### Kana API Limits (Estimated)
- **Route queries**: 100/minute
- **Swap executions**: 50/minute
- **Webhook deliveries**: 1000/hour

### Optimization
```typescript
// Cache route queries for same token pair
const routeCache = new Map();

async function getCachedRoute(params: RouteParams) {
  const key = `${params.fromToken}-${params.toToken}-${params.chainId}`;
  
  if (routeCache.has(key)) {
    const cached = routeCache.get(key);
    if (Date.now() - cached.timestamp < 60000) { // 1 min TTL
      return cached.route;
    }
  }
  
  const route = await aggregator.getRoute(params);
  routeCache.set(key, { route, timestamp: Date.now() });
  return route;
}
```

---

## 8. Next Steps

1. **Week 1**: Set up Kana sandbox accounts and test route simulation
2. **Week 2**: Integrate Mirai SDK for smart account creation
3. **Week 3**: Implement Pack Orchestrator with parallel swap execution
4. **Week 4**: Configure Paymaster for Aptos mainnet
5. **Week 5**: Deploy webhook handlers and monitoring

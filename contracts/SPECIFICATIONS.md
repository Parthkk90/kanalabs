# Smart Contract Specifications

## 1. PackVault Contract (EVM - Base L2)

### Purpose
Manage pooled investments for crypto packs, track user shares, execute rebalancing, and enable withdrawals.

### State Variables
```solidity
// Pack registry
mapping(string => Pack) public packs;

// User balances per pack
mapping(string => mapping(address => uint256)) public userShares;

// Total shares issued per pack
mapping(string => uint256) public totalShares;

// Admin and operator roles
address public admin;
address public operator;
bool public paused;

// Rate limiting
mapping(address => mapping(string => uint256)) public dailyDepositVolume;
mapping(address => uint256) public lastDepositReset;
uint256 public constant MAX_DAILY_DEPOSIT = 1_000_000 * 10**6; // $1M USDC
```

### Data Structures
```solidity
struct Pack {
    string packId;
    string name;
    uint256 totalValueLocked; // in USDC equivalent
    TokenAllocation[] allocations;
    uint256 lastRebalanceTimestamp;
    bool active;
}

struct TokenAllocation {
    address tokenAddress;
    uint256 weightBps; // 10000 = 100%
    uint256 currentBalance;
}

struct DepositParams {
    string packId;
    uint256 usdcAmount;
    address userSmartAccount;
    bytes32 referenceId; // Backend tracking
}

struct WithdrawParams {
    string packId;
    uint256 sharesToBurn;
    address recipient;
    bool convertToStable; // If true, swap to USDC before sending
}
```

### Core Functions

#### Admin Functions
```solidity
// Initialize a new pack
function createPack(
    string memory packId,
    string memory name,
    TokenAllocation[] memory initialAllocations
) external onlyAdmin;

// Update pack allocations (rebalance)
function rebalance(
    string memory packId,
    TokenAllocation[] memory newAllocations
) external onlyAdmin;

// Emergency controls
function pause() external onlyAdmin;
function unpause() external onlyAdmin;
function emergencyWithdrawToken(address token, uint256 amount) external onlyAdmin;

// Transfer admin rights
function transferAdmin(address newAdmin) external onlyAdmin;
```

#### User Functions
```solidity
// Deposit USDC and receive pack shares
function deposit(DepositParams memory params) external whenNotPaused returns (uint256 shares);

// Withdraw by burning shares
function withdraw(WithdrawParams memory params) external whenNotPaused returns (uint256[] memory amounts);

// View functions
function getPackValue(string memory packId) external view returns (uint256 totalValue);
function getUserValue(string memory packId, address user) external view returns (uint256 userValue);
function getPackComposition(string memory packId) external view returns (TokenAllocation[] memory);
```

#### Internal Functions
```solidity
// Calculate shares to mint based on deposit amount
function _calculateShares(string memory packId, uint256 usdcAmount) internal view returns (uint256);

// Execute swaps via Kana Router
function _executeSwaps(
    string memory packId,
    uint256 usdcAmount,
    TokenAllocation[] memory allocations
) internal;

// Rate limiting check
function _checkRateLimit(address user, string memory packId, uint256 amount) internal;

// Price oracle integration
function _getTokenPrice(address token) internal view returns (uint256 priceInUsdc);
```

### Events
```solidity
event PackCreated(string indexed packId, string name, uint256 timestamp);
event PackDeposit(
    address indexed user,
    string indexed packId,
    uint256 usdcAmount,
    uint256 sharesMinted,
    bytes32 referenceId,
    uint256 timestamp
);
event PackWithdraw(
    address indexed user,
    string indexed packId,
    uint256 sharesBurned,
    uint256 usdcValue,
    uint256 timestamp
);
event PackRebalanced(
    string indexed packId,
    TokenAllocation[] newAllocations,
    uint256 timestamp
);
event EmergencyPause(string reason, uint256 timestamp);
event EmergencyUnpause(uint256 timestamp);
```

### Security Requirements
1. **Reentrancy Protection**: Use OpenZeppelin's `ReentrancyGuard` on deposit/withdraw
2. **Access Control**: Use `Ownable2Step` for admin transfer with 2-step confirmation
3. **Pausable**: Implement circuit breaker for emergency scenarios
4. **Rate Limiting**: Daily deposit caps per user to prevent flash loan attacks
5. **Price Oracle Validation**: Revert if Chainlink price deviation >10% from expected
6. **Slippage Protection**: Max 2% slippage on internal swaps via Kana

---

## 2. KanaRouter Integration Contract

### Purpose
Wrapper contract to interact with Kana Aggregator SDK for cross-chain swaps and bridge operations.

### Interface
```solidity
interface IKanaRouter {
    struct SwapIntent {
        address fromToken;
        address toToken;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bytes routeData; // Kana route bytes
    }
    
    function executeSwap(SwapIntent memory intent) external returns (uint256 amountOut);
    
    function simulateRoute(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external view returns (uint256 estimatedOut, uint256 gasCost);
}
```

### Implementation Notes
- Wraps Kana SDK calls into Solidity-compatible format
- Handles approval for Kana Router contract
- Emits events for tracking swap execution
- Supports multi-hop routes (e.g., USDC → WETH → FET)

---

## 3. SmartAccountFactory (Mirai SDK Wrapper)

### Purpose
Deploy and manage user smart accounts across chains, integrating with Mirai SDK.

### Functions
```solidity
function createSmartAccount(
    address owner,
    string memory email
) external returns (address smartAccountAddress);

function getSmartAccount(address owner) external view returns (address);

function setSessionKey(
    address smartAccount,
    address sessionKey,
    uint256 expiryTimestamp
) external;

// Enable automated SIP execution
function authorizeRecurringDeposit(
    address smartAccount,
    string memory packId,
    uint256 maxAmountPerDeposit,
    uint256 frequency
) external;
```

### Session Keys for SIP
- Backend service holds session key with limited permissions
- Can only call `deposit()` on PackVault up to authorized amount
- Expires after 30 days; requires user re-authorization

---

## 4. PriceOracleAdapter

### Purpose
Aggregate price feeds from multiple oracles with fallback logic.

### Supported Oracles
1. **Chainlink**: Primary for BTC, ETH, major tokens
2. **Pyth Network**: Real-time for Solana ecosystem tokens
3. **Kana Internal Pricing**: Fallback from DEX aggregated rates

### Interface
```solidity
interface IPriceOracle {
    function getPrice(address token) external view returns (uint256 priceInUsdc, uint256 confidence);
    function getPrices(address[] memory tokens) external view returns (uint256[] memory prices);
}
```

### Deviation Protection
```solidity
function validatePrice(address token, uint256 executionPrice) external view returns (bool valid) {
    uint256 oraclePrice = getPrice(token);
    uint256 deviation = abs(executionPrice - oraclePrice) * 10000 / oraclePrice;
    return deviation <= 150; // Max 1.5% deviation
}
```

---

## 5. RebalanceGovernor (Future: DAO Governance)

### Purpose
Allow pack creators and community to vote on rebalance proposals.

### Proposal Structure
```solidity
struct RebalanceProposal {
    string packId;
    TokenAllocation[] proposedAllocations;
    string rationale;
    uint256 votingDeadline;
    uint256 yesVotes;
    uint256 noVotes;
    bool executed;
}
```

### Voting Mechanism
- Pack shareholders can vote proportional to their shares
- Requires 60% approval + quorum of 10% of total shares
- 72-hour voting period
- Admin can veto if proposal violates risk parameters

---

## 6. Emergency Circuit Breaker

### Purpose
Multi-sig controlled emergency pause mechanism.

### Trigger Conditions
- Oracle price deviation >20%
- Detected exploit in vault contract
- Regulatory action requiring immediate halt

### Functions
```solidity
function triggerEmergencyStop(string memory reason) external onlyGuardian;
function resumeOperations() external onlyMultiSig;
```

### Guardian Addresses
- Minimum 3 of 5 multi-sig signers
- Include: founder, CTO, external security advisor, legal counsel, community representative

---

## 7. Contract Deployment Order

1. **PriceOracleAdapter** → Deploy and configure oracle sources
2. **KanaRouter** → Deploy with Kana contract addresses
3. **SmartAccountFactory** → Integrate Mirai SDK
4. **PackVault** → Deploy with oracle and router addresses
5. **RebalanceGovernor** → Deploy and link to PackVault (future)

### Constructor Parameters
```solidity
constructor(
    address _priceOracle,
    address _kanaRouter,
    address _paymasterService,
    address _usdcToken
) {
    priceOracle = IPriceOracle(_priceOracle);
    kanaRouter = IKanaRouter(_kanaRouter);
    paymaster = _paymasterService;
    USDC = IERC20(_usdcToken);
}
```

---

## 8. Testing Requirements

### Unit Tests
- Deposit/withdraw with various amounts and users
- Rebalance execution with different allocation changes
- Rate limiting enforcement
- Price oracle fallback logic

### Integration Tests
- Full deposit → swap → vault flow using Kana testnet
- Cross-chain bridge execution for SOL/APT tokens
- Emergency pause/unpause scenarios

### Audit Checklist
- [ ] Reentrancy attack vectors
- [ ] Integer overflow/underflow (use Solidity 0.8+)
- [ ] Access control on admin functions
- [ ] Front-running risks in rebalance execution
- [ ] Flash loan attack surface
- [ ] Oracle manipulation resistance

---

## 9. Gas Optimization Strategies

1. **Batch Deposits**: Allow admin to process multiple user deposits in single tx
2. **Struct Packing**: Optimize storage layout to reduce SLOAD costs
3. **Events Over Storage**: Emit events for historical data instead of storing
4. **Immutable Variables**: Mark oracle/router addresses as immutable
5. **Short-circuit Logic**: Check cheapest conditions first in validation functions

### Estimated Gas Costs (Base L2)
- `deposit()`: ~150k gas (~$0.05 at 10 gwei)
- `withdraw()`: ~180k gas (~$0.06)
- `rebalance()`: ~300k gas (~$0.10)
- `createPack()`: ~500k gas (~$0.15)

---

## 10. Upgrade Path

### V1: Immutable Vaults
- Deploy non-upgradeable contracts for maximum trust
- If bugs found, deploy new vault and migrate user shares

### V2: UUPS Proxy Pattern (Future)
- Implement `UUPSUpgradeable` from OpenZeppelin
- 48-hour timelock on upgrades
- Require multi-sig approval for implementation changes

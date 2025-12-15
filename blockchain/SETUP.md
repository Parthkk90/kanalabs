# Blockchain Development Environment Setup

## 1. Prerequisites

### Required Software
- **Node.js**: v18+ (for Hardhat and testing)
- **Python**: 3.10+ (for Aptos/Move development)
- **Rust**: Latest stable (for Solana/Sealevel programs)
- **Git**: For version control
- **VS Code**: Recommended IDE with Solidity, Move, and Rust extensions

### Package Managers
```bash
npm install -g yarn pnpm
```

---

## 2. EVM Development (Base L2, Ethereum, Polygon)

### Initialize Hardhat Project
```bash
cd contracts
pnpm init
pnpm add -D hardhat @nomicfoundation/hardhat-toolbox
pnpm add @openzeppelin/contracts @openzeppelin/contracts-upgradeable
```

### hardhat.config.js
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");

const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || "";

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // Base Sepolia Testnet
    baseSepolia: {
      url: "https://sepolia.base.org",
      accounts: [PRIVATE_KEY],
      chainId: 84532
    },
    // Base Mainnet
    base: {
      url: "https://mainnet.base.org",
      accounts: [PRIVATE_KEY],
      chainId: 8453
    },
    // Polygon Mumbai Testnet
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [PRIVATE_KEY],
      chainId: 80001
    },
    // Local Hardhat Network
    hardhat: {
      chainId: 31337
    }
  },
  etherscan: {
    apiKey: {
      baseSepolia: BASESCAN_API_KEY,
      base: BASESCAN_API_KEY
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  }
};
```

### Directory Structure
```
contracts/
├── contracts/
│   ├── PackVault.sol
│   ├── KanaRouter.sol
│   ├── PriceOracleAdapter.sol
│   ├── SmartAccountFactory.sol
│   └── interfaces/
│       ├── IKanaRouter.sol
│       ├── IPriceOracle.sol
│       └── IPaymaster.sol
├── scripts/
│   ├── deploy-vault.js
│   ├── deploy-router.js
│   └── verify.js
├── test/
│   ├── PackVault.test.js
│   ├── Rebalance.test.js
│   └── Integration.test.js
├── hardhat.config.js
└── package.json
```

### Sample Deployment Script
```javascript
// scripts/deploy-vault.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // Deploy dependencies first
  const PriceOracle = await hre.ethers.getContractFactory("PriceOracleAdapter");
  const priceOracle = await PriceOracle.deploy();
  await priceOracle.waitForDeployment();
  console.log("PriceOracle deployed to:", await priceOracle.getAddress());

  const KanaRouter = await hre.ethers.getContractFactory("KanaRouter");
  const kanaRouter = await KanaRouter.deploy();
  await kanaRouter.waitForDeployment();
  console.log("KanaRouter deployed to:", await kanaRouter.getAddress());

  // Deploy PackVault
  const PackVault = await hre.ethers.getContractFactory("PackVault");
  const USDC_BASE = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // Base mainnet USDC
  
  const packVault = await PackVault.deploy(
    await priceOracle.getAddress(),
    await kanaRouter.getAddress(),
    ethers.ZeroAddress, // Paymaster (set later)
    USDC_BASE
  );
  await packVault.waitForDeployment();
  
  console.log("PackVault deployed to:", await packVault.getAddress());
  
  // Verify on Basescan
  if (hre.network.name !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await packVault.deploymentTransaction().wait(5);
    await hre.run("verify:verify", {
      address: await packVault.getAddress(),
      constructorArguments: [
        await priceOracle.getAddress(),
        await kanaRouter.getAddress(),
        ethers.ZeroAddress,
        USDC_BASE
      ]
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

---

## 3. Aptos Development (Move Language)

### Install Aptos CLI
```bash
# macOS/Linux
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Verify installation
aptos --version
```

### Initialize Move Project
```bash
mkdir aptos-contracts
cd aptos-contracts
aptos move init --name chota_crypto
```

### Move.toml Configuration
```toml
[package]
name = "chota_crypto"
version = "1.0.0"
authors = ["Chota Crypto Team"]

[addresses]
chota_crypto = "_"

[dependencies.AptosFramework]
git = "https://github.com/aptos-labs/aptos-core.git"
rev = "mainnet"
subdir = "aptos-move/framework/aptos-framework"

[dependencies.AptosStdlib]
git = "https://github.com/aptos-labs/aptos-core.git"
rev = "mainnet"
subdir = "aptos-move/framework/aptos-stdlib"
```

### Directory Structure
```
aptos-contracts/
├── sources/
│   ├── pack_vault.move
│   └── smart_account.move
├── tests/
│   └── pack_vault_tests.move
├── scripts/
│   └── deploy.sh
└── Move.toml
```

### Sample Pack Vault Module (Move)
```move
module chota_crypto::pack_vault {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::account;
    
    struct PackInfo has key {
        pack_id: vector<u8>,
        total_shares: u64,
        user_shares: SimpleMap<address, u64>
    }
    
    public entry fun deposit(
        user: &signer,
        pack_id: vector<u8>,
        amount: u64
    ) {
        // Implementation
    }
    
    public entry fun withdraw(
        user: &signer,
        pack_id: vector<u8>,
        shares: u64
    ) {
        // Implementation
    }
}
```

### Deploy to Testnet
```bash
# Compile
aptos move compile

# Test
aptos move test

# Publish to devnet
aptos move publish \
  --named-addresses chota_crypto=0xYOUR_ADDRESS \
  --network devnet
```

---

## 4. Solana Development (Rust/Anchor)

### Install Solana CLI & Anchor
```bash
# Install Solana
sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest
```

### Initialize Anchor Project
```bash
anchor init solana-packs
cd solana-packs
```

### Anchor.toml Configuration
```toml
[features]
seeds = false
skip-lint = false

[programs.devnet]
solana_packs = "PROGRAM_ID_HERE"

[registry]
url = "https://api.apr.dev"

[provider]
cluster = "devnet"
wallet = "~/.config/solana/id.json"

[scripts]
test = "yarn run ts-mocha -p ./tsconfig.json -t 1000000 tests/**/*.ts"
```

### Program Structure
```
solana-packs/
├── programs/
│   └── solana-packs/
│       └── src/
│           ├── lib.rs
│           ├── instructions/
│           │   ├── deposit.rs
│           │   ├── withdraw.rs
│           │   └── rebalance.rs
│           └── state/
│               └── pack.rs
├── tests/
│   └── solana-packs.ts
└── Anchor.toml
```

### Sample Deposit Instruction (Rust)
```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(mut)]
    pub pack_vault: Account<'info, PackVault>,
    
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<Deposit>, amount: u64) -> Result<()> {
    // Transfer tokens from user to vault
    let cpi_accounts = Transfer {
        from: ctx.accounts.user_token_account.to_account_info(),
        to: ctx.accounts.vault_token_account.to_account_info(),
        authority: ctx.accounts.user.to_account_info(),
    };
    
    let cpi_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts
    );
    
    token::transfer(cpi_ctx, amount)?;
    
    // Update pack shares
    ctx.accounts.pack_vault.total_shares += amount;
    
    Ok(())
}
```

---

## 5. Testing & CI/CD

### Local Testing
```bash
# EVM (Hardhat)
cd contracts
pnpm test
pnpm coverage

# Aptos
cd aptos-contracts
aptos move test

# Solana
cd solana-packs
anchor test
```

### GitHub Actions Workflow
```yaml
# .github/workflows/contracts.yml
name: Smart Contract CI

on: [push, pull_request]

jobs:
  test-evm:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: cd contracts && pnpm install
      - run: cd contracts && pnpm test
      
  test-aptos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Aptos CLI
        run: curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3
      - run: cd aptos-contracts && aptos move test
      
  test-solana:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - name: Install Solana
        run: sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
      - run: cd solana-packs && anchor test
```

---

## 6. Environment Variables

### .env.example
```bash
# EVM
DEPLOYER_PRIVATE_KEY=your_private_key_here
BASESCAN_API_KEY=your_basescan_api_key
ALCHEMY_API_KEY=your_alchemy_key
COINBASE_COMMERCE_API_KEY=for_gas_sponsorship

# Kana Integration
KANA_API_KEY=your_kana_api_key
KANA_ROUTER_ADDRESS=0x...
KANA_PAYMASTER_ADDRESS=0x...

# Oracles
CHAINLINK_ORACLE_ADDRESS=0x...
PYTH_ORACLE_ADDRESS=0x...

# Aptos
APTOS_PRIVATE_KEY=your_aptos_key
APTOS_ACCOUNT_ADDRESS=0x...

# Solana
SOLANA_PRIVATE_KEY=[your,solana,keypair,array]
SOLANA_RPC_URL=https://api.devnet.solana.com
```

---

## 7. Local Development

### Run Local Nodes
```bash
# Hardhat local node
cd contracts
pnpm hardhat node

# Solana local validator
solana-test-validator

# Aptos local node
aptos node run-local-testnet --with-faucet
```

### Fund Test Accounts
```bash
# Base Sepolia faucet
https://www.coinbase.com/faucets/base-ethereum-goerli-faucet

# Aptos devnet faucet
aptos account fund-with-faucet --account YOUR_ADDRESS

# Solana devnet airdrop
solana airdrop 2 YOUR_ADDRESS --url devnet
```

---

## 8. Next Steps

1. **Week 1**: Set up Hardhat project and deploy PackVault to Base Sepolia
2. **Week 2**: Implement Kana Router integration contract
3. **Week 3**: Add Aptos Move module for Paymaster integration
4. **Week 4**: Solana program for Jupiter-based pack execution
5. **Week 5**: Integration testing across all chains

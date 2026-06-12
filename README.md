# ArcNames — .arc Name Service

A decentralized name service built on [Arc Testnet](https://arc.network) by Circle. Register human-readable `.arc` names, pay with USDC, and own them as on-chain records.

## Live Demo

> Deploy to GitHub Pages and update this link.

## Features

- **Search & Register** — Check availability and register `.arc` names with USDC
- **My Names** — Manage your registered names, renew, transfer, set primary
- **Marketplace** — List names for sale, buy from others (2.5% protocol fee)
- **Profile** — Set on-chain text records: display name, bio, avatar, social links
- **Stats** — Live protocol metrics from on-chain events
- **Bulk Cart** — Register multiple names in one flow
- **Watchlist** — Track names you want to register

## Smart Contracts (Arc Testnet)

| Contract | Address |
|---|---|
| ArcNameRegistry | `0xBE267dcfC6eeB905e788358eAA792e2eCcB23F01` |
| ArcNameMarket | `0xADd462229371E79bF5f65EFFCd8C3fb21815eD99` |
| ProfileRegistry | `0x659AcAC311050D57859768d3dfB6fcDB8993679a` |
| USDC (Arc native) | `0x3600000000000000000000000000000000000000` |

## Network

| Parameter | Value |
|---|---|
| Network | Arc Testnet |
| Chain ID | 5042002 |
| RPC | https://rpc.testnet.arc.network |
| Explorer | https://testnet.arcscan.app |
| Faucet | https://faucet.circle.com |

## Tech Stack

- Vanilla HTML/CSS/JS — zero build step, single file
- [ethers.js v5](https://docs.ethers.org/v5/) — wallet & contract interaction
- [MetaMask](https://metamask.io/) — browser wallet
- Solidity `^0.8.20` — smart contracts

## Getting Started

### Use the live site
1. Install [MetaMask](https://metamask.io/download/)
2. Add Arc Testnet (Chain ID: 5042002, RPC: https://rpc.testnet.arc.network)
3. Get test USDC from [faucet.circle.com](https://faucet.circle.com)
4. Open the site and connect your wallet

### Run locally
Just open `index.html` in any browser — no build step required.

### Deploy your own contracts
See [`contracts/deploy-instructions.md`](contracts/deploy-instructions.md) for step-by-step Remix IDE instructions.

After deploying, update these constants in `index.html`:
```js
const CONTRACT_ADDRESS = 'YOUR_REGISTRY_ADDRESS';
const MARKET_ADDRESS   = 'YOUR_MARKET_ADDRESS';
const PROFILE_ADDRESS  = 'YOUR_PROFILE_ADDRESS';
```

## Contract Architecture

```
ArcNameRegistry   — Core name registration, renewal, transfer, primary name
ArcNameMarket     — P2P marketplace with escrow, 2.5% fee
ProfileRegistry   — On-chain text records (ENS EIP-634 inspired)
```

## Pricing

| Name Length | Annual Price |
|---|---|
| 2 characters | $50 USDC |
| 3 characters | $20 USDC |
| 4 characters | $10 USDC |
| 5+ characters | $2 USDC |

## License

MIT

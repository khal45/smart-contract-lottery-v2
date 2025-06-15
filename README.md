# Smart Contract Lottery

## Description

A provably fair smart contract lottery built with Foundry. Users can enter the lottery by sending ETH, and a random winner is selected at regular intervals using Chainlink VRF and Automation.  
This project was built as part of the [Cyfrin Foundry Course](https://github.com/Cyfrin/foundry-full-course-cu).

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Getting Started](#getting-started)
  - [Deploy](#deploy)
  - [Testing](#testing)
  - [Test Coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)

## Installation

**Foundry**

- Follow the instructions on [getfoundry](https://book.getfoundry.sh/getting-started/installation) to install Foundry on your local machine

## Usage

### Getting Started

Follow these steps to run this project locally:

- Clone the Github repo
- Install foundry on your machine
- Set your sepolia and mainnet rpc urls in your .env file. You can get them from [alchemy](https://www.alchemy.com/).
- Set your etherscan api key if you want to verify your contract on [Etherscan](https://etherscan.io/).

```# .env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
ETHERSCAN_API_KEY=your-api-key
PRIVATE_KEY=your-private-key # NEVER commit this
```

WARNING!! DO NOT STORE YOUR PRIVATE KEY IN PLAIN TEXT IN A .ENV FILE EVEN IF IT IS NOT ASSOCIATED WITH REAL MONEY! WATCH THIS VIDEO BY [CYFRIN AUDITS](https://youtu.be/VQe7cIpaE54?si=GDZAdaltdRO8-Ond) FOR BEST PRACTICES ON HANDLING PRIVATE KEYS

- Install the necessary packages with

`make install`

### Deploy

`make deploy-sepolia`

### Testing

Local test

`make test`

Sepolia test

`make test-sepolia`

### Test Coverage

`forge coverage`

## Deployment to a testnet or mainnet

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

`make deploy-sepolia`

This will set up a ChainlinkVRF Subscription for you. If you already have one, update it in the scripts/HelperConfig.s.sol file. It will also automatically add your contract as a consumer.

3. Register a Chainlink Automation Upkeep

   [you can follow the documentation if you get lost](https://docs.chain.link/chainlink-automation/compatible-contracts)

   Go to [automation.chain.link](https://automation.chain.link/new) and register a new upkeep. Choose Custom logic as your trigger mechanism for automation.

### Scripts

After deploying to a testnet or local net, you can run the scripts.

Using cast deployed locally example:

```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.01ether --account <ACCOUNT_NAME> --rpc-url $SEPOLIA_RPC_URL
```

or, to create a ChainlinkVRF Subscription:

```
make createSubscription-sepolia
```

### Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

## Formatting

To run code formatting:

```
forge fmt
```

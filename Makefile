-include .env

.PHONY: all test deploy

build:; forge build

test:; forge test

test-sepolia:; forge test --fork-url $(SEPOLIA_RPC_URL)

gas-report:; forge test --gas-report 

coverage:; forge coverage --report debug > coverage.txt

install:; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 && forge install transmissions11/solmate@v6 

deploy-raffle-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account devWallet --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-raffle-anvil:
	@forge script script/DeployRaffle.s.sol:DeployRaffle

createSubscription-sepolia:
	@forge script script/Interactions.s.sol:CreateSubscription --rpc-url $(SEPOLIA_RPC_URL) --account devWallet --broadcast --verify

create-subscription-anvil: 
	@forge script script/Interactions.s.sol:CreateSubscription 

addConsumer-sepolia:
	@forge script script/Interactions.s.sol:AddConsumer --rpc-url $(SEPOLIA_RPC_URL) --account devWallet --broadcast --verify 

fundSubscription-sepolia:
	@forge script script/Interactions.s.sol:FundSubscription --rpc-url $(SEPOLIA_RPC_URL) --account devWallet --broadcast --verify 


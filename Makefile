# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install:; forge install
update:; forge update

# Build & test
build  :; forge build
test   :; forge test --fork-url sepolia
trace   :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt

# -- Integration Test ---
setup_integration_test:; local_deploy_erc1967_proxy_factory local_deploy_registry local_deploy_client
local_deploy_erc1967_proxy_factory:; forge script DeployERC1967ProxyFactory --rpc-url local --broadcast --json

# --- Deploy ---
# Deploy the registry
local_deploy_registry   :; forge script DeployLPNRegistry --rpc-url local --broadcast --json
testnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url sepolia --verify --broadcast -vvvv --slow --skip-simulation --priority-gas-price 0.1gwei
mainnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url mainnet --verify --broadcast -vvvv --slow --priority-gas-price 0.5gwei

# Deploy a client
local_deploy_client:; forge script DeploySampleClient --rpc-url local --broadcast --json
testnet_deploy_client:; forge script DeploySampleClient --rpc-url sepolia --broadcast -vvvv --slow

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
setup_integration_test: local_deploy_erc1967_proxy_factory local_deploy_registry local_deploy_client
local_deploy_erc1967_proxy_factory:; sh script/deploy_erc1967_proxy_factory.sh

# --- Deploy ---
# Deploy the registry
local_deploy_registry   :; forge script DeployLPNRegistry --rpc-url local --broadcast --json
testnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url sepolia --broadcast -vvvv --slow

# Deploy a client
local_deploy_client:; forge script DeploySampleClient --rpc-url local --broadcast --json
testnet_deploy_client:; forge script DeploySampleClient --rpc-url sepolia --broadcast -vvvv --slow

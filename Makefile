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
local_deploy_erc1967_proxy_factory:; sh script/deploy_erc1967_proxy_factory.sh

# --- Deploy ---
# Deploy the registry
local_deploy_registry   :; forge script DeployLPNRegistry --rpc-url local --broadcast --json
testnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url sepolia --verify --broadcast -vvvv --slow --skip-simulation --priority-gas-price 0.1gwei
mainnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url mainnet --verify --broadcast -vvvv --slow --priority-gas-price 1.5gwei

# Deploy a client
local_deploy_client:; forge script DeploySampleClient --rpc-url local --broadcast --json
testnet_deploy_client:; forge script DeploySampleClient --rpc-url sepolia --broadcast -vvvv --slow

# --- Etherscan Verify ---
# testnet_verify_registry :; forge verify-contract --chain sepolia --num-of-optimizations 200 --watch 0xbbCea8781A255BE7AaB1228d1e096885c172C13b LPNRegistryV0
# mainnet_verify_registry :; forge verify-contract --chain mainnet --num-of-optimizations 200 --watch --constructor-args $(shell cast abi-encode "constructor()" -n "LPNRegistryV0") $(shell forge inspect LPNRegistryV0 deployedBytecode) ${ETHERSCAN_KEY}
# testnet_verify_client :; forge verify-contract --chain sepolia --num-of-optimizations 200 --watch --constructor-args $(shell cast abi-encode "constructor(address,address)" $(shell forge inspect DeploySampleClient deployed) $(shell forge inspect LagrangeLoonsNFT deployed)) $(shell forge inspect AirdropNFTCrosschain deployedBytecode) ${ETHERSCAN_KEY}

# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install :; forge install
update  :; forge update

# Build & test
build    :; forge build
test     :; forge test --fork-url sepolia
trace    :; forge test -vvv
clean    :; forge clean
snapshot :; forge snapshot
fmt      :; forge fmt

# -- Integration Test ---
setup_integration_test : local_deploy_erc1967_proxy_factory local_deploy_registry local_deploy_clients
local_deploy_erc1967_proxy_factory :; forge script DeployERC1967ProxyFactory --rpc-url local --broadcast --skip-simulation -vvvv --json  --ffi
base_testnet_deploy_erc1967_proxy_factory :; forge script DeployERC1967ProxyFactory --rpc-url baseSepolia --verify --broadcast -vvvv --ffi --slow

# --- Deploy ---
# Deploy the registry
local_deploy_registry        :; forge script DeployLPNRegistry --rpc-url local --broadcast -vvvv --json --ffi
testnet_deploy_registry      :; forge script DeployLPNRegistry --rpc-url sepolia --verify --broadcast -vvvv --ffi --slow --priority-gas-price 0.1gwei
mainnet_deploy_registry      :; forge script DeployLPNRegistry --rpc-url mainnet --verify --broadcast -vvvv --ffi --slow --priority-gas-price 0.5gwei
base_testnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url baseSepolia --verify --broadcast -vvvv --ffi --slow
base_mainnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url base --verify --broadcast -vvvv --ffi --slow

# Deploy clients
local_deploy_clients   :; forge script DeployClients --rpc-url local --broadcast -vvvv --ffi
testnet_deploy_clients :; forge script DeployClients --rpc-url sepolia --verify --broadcast -vvvv --slow --priority-gas-price 0.1gwei
mainnet_deploy_clients :; forge script DeployClients --rpc-url mainnet --verify --broadcast -vvvv --slow --priority-gas-price 0.5gwei
base_testnet_deploy_clients :; forge script DeployClients --rpc-url baseSepolia --verify --broadcast -vvvv --slow
base_testnet_deploy_clients :; forge script DeployClients --rpc-url base --verify --broadcast -vvvv --slow

# Run Queries
base_testnet_query :; forge script Query --rpc-url baseSepolia --broadcast -vvvv --slow
base_mainnet_query :; forge script Query --rpc-url base --broadcast -vvvv --slow

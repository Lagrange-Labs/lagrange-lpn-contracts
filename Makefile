# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# VERBOSITY=-vvvv
VERBOSITY=
LOCAL_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${LOCAL_DEPLOY_FLAGS}

DEPLOY_PROXY_FACTORY_CMD=forge script DeployERC1967ProxyFactory --rpc-url
DEPLOY_REGISTRY_CMD=forge script DeployLPNRegistry --rpc-url
DEPLOY_CLIENTS_CMD=forge script DeployClients --rpc-url
QUERY_CMD=forge script Query --rpc-url

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

local_deploy_erc1967_proxy_factory        :; ${DEPLOY_PROXY_FACTORY_CMD} local ${LOCAL_DEPLOY_FLAGS} --json
base_testnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} baseSepolia ${DEPLOY_FLAGS}

# -- Testnet Base Integration Test --
testnet_integration_test : testnet_deploy_registry base_testnet_deploy_registry testnet_deploy_clients base_testnet_deploy_clients base_testnet_query

# --- Deploy ---
# Deploy the registry
local_deploy_registry        :; ${DEPLOY_REGISTRY_CMD} local ${LOCAL_DEPLOY_FLAGS} --json
testnet_deploy_registry      :; ${DEPLOY_REGISTRY_CMD} sepolia ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
mainnet_deploy_registry      :; ${DEPLOY_REGISTRY_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei
base_testnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} base ${DEPLOY_FLAGS}

# Deploy clients
local_deploy_clients        :; ${DEPLOY_CLIENTS_CMD} local ${LOCAL_DEPLOY_FLAGS}
testnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} sepolia ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
mainnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei
base_testnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} base ${DEPLOY_FLAGS}

# Run Queries
testnet_query :; ${QUERY_CMD} sepolia ${DEPLOY_FLAGS}
base_testnet_query :; ${QUERY_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_query :; ${QUERY_CMD} base ${DEPLOY_FLAGS}

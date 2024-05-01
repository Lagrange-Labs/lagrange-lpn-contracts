# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# VERBOSITY=-vvvv
VERBOSITY=
LOCAL_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${LOCAL_DEPLOY_FLAGS}
MAINNET_DEPLOYER=--account v0_owner

DEPLOY_PROXY_FACTORY_CMD=forge script DeployERC1967ProxyFactory --rpc-url
DEPLOY_REGISTRY_CMD=forge script DeployLPNRegistry --rpc-url
DEPLOY_CLIENTS_CMD=forge script DeployClients --rpc-url
QUERY_CMD=forge script Query --rpc-url
WITHDRAW_FEES_CMD=forge script WithdrawFees --rpc-url
BRIDGE_CMD=forge script Bridge --rpc-url

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
mainnet_deploy_registry      :; ${DEPLOY_REGISTRY_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei ${MAINNET_DEPLOYER}
base_testnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Deploy clients
local_deploy_clients        :; ${DEPLOY_CLIENTS_CMD} local ${LOCAL_DEPLOY_FLAGS}
testnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} sepolia ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
mainnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei --account v0_owner
base_testnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Run Queries
testnet_query :; ${QUERY_CMD} sepolia ${DEPLOY_FLAGS}
base_testnet_query :; ${QUERY_CMD} baseSepolia ${DEPLOY_FLAGS}
base_mainnet_query :; ${QUERY_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Withdraw fees
mainnet_withdraw_fees :; ${WITHDRAW_FEES_CMD} mainnet ${LOCAL_DEPLOY_FLAGS} --account v0_owner --sender 0x5d9aB52c84D0bA59A3143982a7Ba34BEE079f776 --priority-gas-price 0.01gwei

# Bridge
mainnet_bridge_base :; ${BRIDGE_CMD} mainnet ${LOCAL_DEPLOY_FLAGS} --account v0_relayer --sender 0x373a4796Eb758a416366F561206E0472B508eCd1 --priority-gas-price 0.01gwei

base_mainnet_deployment : base_mainnet_deploy_registry base_mainnet_deploy_clients

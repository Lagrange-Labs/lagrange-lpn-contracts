# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

VERBOSITY=-vvvv
# VERBOSITY=
LOCAL_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${LOCAL_DEPLOY_FLAGS}
MAINNET_DEPLOYER=--account v0_owner --sender ${DEPLOYER_ADDR}
DEPLOY_PROXY_FACTORY_CMD=forge script DeployERC1967ProxyFactory --rpc-url
DEPLOY_REGISTRY_CMD=forge script DeployLPNRegistryV1 --rpc-url
DEPLOY_REGISTRY_V0_CMD=forge script DeployLPNRegistryV0 --rpc-url
DEPLOY_CLIENTS_CMD=forge script DeployClients --rpc-url
DEPLOY_QUERY_CLIENT_CMD=forge script DeployLPNQueryV1 --rpc-url
DEPLOY_TEST_ERC20_CMD=forge script DeployTestERC20 --rpc-url
DEPLOY_ERC20_DISTRIBUTOR_CMD=forge script DeployERC20Distributor --rpc-url
DEPLOY_PENG_CMD=forge script DeployLayeredPenguins --rpc-url
QUERY_CMD=forge script Query --rpc-url
WITHDRAW_FEES_CMD=forge script WithdrawFees --rpc-url
BRIDGE_CMD=forge script Bridge --rpc-url
STAKE_CMD=forge script Stake --rpc-url

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
holesky_testnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} holesky ${DEPLOY_FLAGS}
base_testnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} base_sepolia ${DEPLOY_FLAGS}
fraxtal_testnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} fraxtal_testnet ${DEPLOY_FLAGS}
fraxtal_mainnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} fraxtal ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
mantle_mainnet_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} mantle ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER} --with-gas-price 20000000 -g 4000000

# -- Testnet Base Integration Test --
testnet_integration_test : testnet_deploy_registry base_testnet_deploy_registry testnet_deploy_clients base_testnet_deploy_clients base_testnet_query
fraxtal_testnet_integration_test : fraxtal_testnet_deploy_registry fraxtal_testnet_deploy_clients fraxtal_testnet_query

# --- Deploy ---
# Deploy the registry
local_deploy_registry           :; ${DEPLOY_REGISTRY_CMD} local ${LOCAL_DEPLOY_FLAGS} --json
testnet_deploy_registry         :; ${DEPLOY_REGISTRY_CMD} sepolia ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
holesky_testnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} holesky ${DEPLOY_FLAGS} --legacy
mainnet_deploy_registry         :; ${DEPLOY_REGISTRY_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei ${MAINNET_DEPLOYER}
mainnet_deploy_registry_v0      :; ${DEPLOY_REGISTRY_V0_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei ${MAINNET_DEPLOYER}
base_testnet_deploy_registry    :; ${DEPLOY_REGISTRY_CMD} base_sepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_registry    :; ${DEPLOY_REGISTRY_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
fraxtal_testnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} fraxtal_testnet ${DEPLOY_FLAGS}
fraxtal_mainnet_deploy_registry :; ${DEPLOY_REGISTRY_CMD} fraxtal ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
mantle_testnet_deploy_registry  :; ${DEPLOY_REGISTRY_CMD} mantle_sepolia ${DEPLOY_FLAGS} --with-gas-price 20000000 -g 4000000
mantle_mainnet_deploy_registry  :; ${DEPLOY_REGISTRY_CMD} mantle ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER} --legacy -g 1000000
polygon_deploy_registry         :; ${DEPLOY_REGISTRY_CMD} polygon_zkevm ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Deploy clients
local_deploy_clients        :; ${DEPLOY_CLIENTS_CMD} local ${LOCAL_DEPLOY_FLAGS}
testnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} sepolia ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
holesky_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} holesky ${DEPLOY_FLAGS} --gas-estimate-multiplier 1000 # multiply estimate by 10
holesky_deploy_test_erc20   :; ${DEPLOY_TEST_ERC20_CMD} holesky ${DEPLOY_FLAGS} --gas-estimate-multiplier 1000 # --sender ${DEPLOYER_ADDR}
mainnet_deploy_clients      :; ${DEPLOY_CLIENTS_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei --account v0_owner
base_testnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} base_sepolia ${DEPLOY_FLAGS}
base_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
fraxtal_testnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} fraxtal_testnet ${DEPLOY_FLAGS}
fraxtal_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} fraxtal ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
mantle_testnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} mantle_sepolia ${DEPLOY_FLAGS} --with-gas-price 20000000 -g 4000000
mantle_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} mantle ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER} --with-gas-price 20000000 -g 4000000
polygon_mainnet_deploy_clients :; ${DEPLOY_CLIENTS_CMD} polygon_zkevm ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Deploy Query Clients
holesky_deploy_query_client :; ${DEPLOY_QUERY_CLIENT_CMD} holesky ${DEPLOY_FLAGS} --gas-estimate-multiplier 1000 # multiply estimate by 10
mainnet_deploy_query_client :; ${DEPLOY_QUERY_CLIENT_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei --account v0_owner

# Deploy Examples
holesky_deploy_erc20_distributor :; ${DEPLOY_ERC20_DISTRIBUTOR_CMD} holesky ${DEPLOY_FLAGS} --gas-estimate-multiplier 1000 # multiply estimate by 10
mainnet_deploy_layered_penguins :; ${DEPLOY_PENG_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei --account v0_owner

# Run Queries
testnet_query :; ${QUERY_CMD} sepolia ${DEPLOY_FLAGS}
holesky_query :; ${QUERY_CMD} holesky ${DEPLOY_FLAGS}
base_testnet_query :; ${QUERY_CMD} base_sepolia ${DEPLOY_FLAGS}
fraxtal_testnet_query :; ${QUERY_CMD} fraxtal_testnet ${DEPLOY_FLAGS}
mainnet_query :; ${QUERY_CMD} mainnet ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
base_mainnet_query :; ${QUERY_CMD} base ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
fraxtal_mainnet_query :; ${QUERY_CMD} fraxtal ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
mantle_mainnet_query :; ${QUERY_CMD} mantle ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER} --with-gas-price 20000000 -g 4000000
polygon_mainnet_query :; ${QUERY_CMD} polygon_zkevm ${DEPLOY_FLAGS} ${MAINNET_DEPLOYER}

# Withdraw fees
mainnet_withdraw_fees :; ${WITHDRAW_FEES_CMD} mainnet ${LOCAL_DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
base_withdraw_fees    :; ${WITHDRAW_FEES_CMD} base ${LOCAL_DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
fraxtal_withdraw_fees :; ${WITHDRAW_FEES_CMD} fraxtal ${LOCAL_DEPLOY_FLAGS} ${MAINNET_DEPLOYER}
mantle_withdraw_fees  :; ${WITHDRAW_FEES_CMD} mantle ${LOCAL_DEPLOY_FLAGS} ${MAINNET_DEPLOYER} --legacy -g 1000000

# Bridge
mainnet_bridge_base    :; ${BRIDGE_CMD} mainnet ${LOCAL_DEPLOY_FLAGS} --account v0_relayer --sender 0x373a4796Eb758a416366F561206E0472B508eCd1 --priority-gas-price 0.01gwei
holesky_bridge_fraxtal :; ${BRIDGE_CMD} holesky ${LOCAL_DEPLOY_FLAGS} --priority-gas-price 0.01gwei -vvvv

base_mainnet_deployment : base_mainnet_deploy_registry base_mainnet_deploy_clients

# Stake
holesky_stake :; ${STAKE_CMD} holesky ${LOCAL_DEPLOY_FLAGS} --priority-gas-price 0.01gwei -vvvv --skip-simulation

base_mainnet_deployment : base_mainnet_deploy_registry base_mainnet_deploy_clients

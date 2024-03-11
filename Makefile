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

# --- Deploy ---
# First fund the CREATE2 deployer EOA
fund_deployer:; cast send 0x3fab184622dc19b6109349b94811493bf2a45362 \
				--value 1.1ether \
				--private-key ${PRIVATE_KEY}

# Then deploy the CREATE2 Deployer contract (it will not exist on local anvil)
local_deploy_create2:; cast publish --rpc-url local 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222

# Then deploy the factories
local_deploy_registry   :; forge script DeployLPNRegistry --rpc-url local --broadcast -v --silent --json
testnet_deploy_registry :; forge script DeployLPNRegistry --rpc-url sepolia --broadcast -vvvv --skip-simulation --slow

# Then deploy client
local_deploy_client:; forge script DeploySampleClient --rpc-url local --broadcast -vvvv
testnet_deploy_client:; forge script DeploySampleClient --rpc-url sepolia --broadcast -vvvv --skip-simulation --slow

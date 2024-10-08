# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

VERBOSITY=-vvvv
BASE_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${BASE_DEPLOY_FLAGS}
MAINNET_DEPLOYER=--account lpn_owner --sender ${DEPLOYER_ADDR}

# Define chains
CHAINS=local sepolia holesky mainnet base_sepolia base fraxtal_testnet fraxtal mantle_sepolia mantle polygon_zkevm

# Find all .s.sol files in the scripts directory and its subdirectories
SCRIPT_FILES := $(shell find ./script -name '*.s.sol' -type f)

# Extract script names without .s.sol extension to get the ContractName, e.g. DeployLPNRegistryV1
SCRIPT_NAMES := $(patsubst %.s.sol,%,$(notdir $(SCRIPT_FILES)))

# Function to get chain-specific flags
define get-chain-flags
$(if $(filter mantle% polygon_zkevm%,$(1)),--with-gas-price 20000000 -g 4000000,\
$(if $(filter mainnet base% fraxtal%,$(1)),--priority-gas-price 0.5gwei,))
endef

# Generate rules for all scripts and chains
# e.g. DeployLPNRegistryV1_mainnet
define make-command-rule
$(1)_$(2): CHAIN_FLAGS = $(call get-chain-flags,$(2))
$(1)_$(2):
	forge script $(1) --rpc-url $(2) $${DEPLOY_FLAGS} $${CHAIN_FLAGS} $$(if $$(findstring mainnet,$(2)),$${MAINNET_DEPLOYER},)
endef

$(foreach chain,${CHAINS},$(foreach script,${SCRIPT_NAMES},$(eval $(call make-command-rule,${script},${chain}))))

# Other non-generic rules
install :; forge install
update  :; forge update
build   :; forge build
test    :; forge test --fork-url sepolia
trace   :; forge test -vvv
clean   :; forge clean
snapshot:; forge snapshot
fmt     :; forge fmt

# List available scripts
list-scripts:
	@echo "Available scripts:"
	@for script in $(SCRIPT_NAMES); do echo "  $$script"; done

.PHONY: $(CHAINS) $(SCRIPT_NAMES) list-scripts

# Default target to show usage
.DEFAULT_GOAL := usage

usage:
	@echo "Usage: make <script_name>_<chain>"
	@echo "Example: make DeployERC1967ProxyFactory_local"
	@echo ""
	@echo "Available chains: $(CHAINS)"
	@echo ""
	@echo "To see available scripts, run: make list-scripts"

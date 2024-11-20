# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

VERBOSITY=-vvvv
BASE_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${BASE_DEPLOY_FLAGS}
MAINNET_DEPLOYER=--account lpn_owner

# Define chains
CHAINS=anvil sepolia holesky_dev holesky mainnet base_sepolia base fraxtal_testnet fraxtal mantle_sepolia mantle polygon_zkevm

# Find all .s.sol files in the scripts directory and its subdirectories
SCRIPT_FILES := $(shell find ./script -name '*.s.sol' -type f)

# Extract script names without .s.sol extension to get the ContractName, e.g. DeployLPNRegistryV1
SCRIPT_NAMES := $(patsubst %.s.sol,%,$(notdir $(SCRIPT_FILES)))

# Function to get chain-specific flags
define get-chain-flags
$(if $(filter mantle% polygon_zkevm%,$(1)),--with-gas-price 20000000,\
$(if $(filter mainnet,$(1)),--priority-gas-price 0.5gwei,))
endef

# Function to determine if MAINNET_DEPLOYER should be used
define use-mainnet-deployer
$(if $(or $(findstring local,$(1)),$(findstring sepolia,$(1)),$(findstring holesky,$(1)),$(findstring testnet,$(1))),,${MAINNET_DEPLOYER})
endef

# EVM version management
FOUNDRY_TOML=foundry.toml
BACKUP_TOML=foundry.toml.bak
EVM_CANCUN_LINE=evm_version = "cancun"
EVM_SHANGHAI_LINE=evm_version = "shanghai"

# Function to switch EVM version from `cancun` => `shanghai`
# This is used for the `mantle` blockchain
define switch-evm-version
	@if [ -f "${FOUNDRY_TOML}" ]; then \
		cp ${FOUNDRY_TOML} ${BACKUP_TOML}; \
		sed -i.tmp '/evm_version/s/\"cancun\"/\"shanghai\"/' ${FOUNDRY_TOML} && rm -f ${FOUNDRY_TOML}.tmp; \
	fi
endef

# Function to restore EVM version from `shanghai` => `cancun`
define restore-evm-version
	@if [ -f "${BACKUP_TOML}" ]; then \
		mv ${BACKUP_TOML} ${FOUNDRY_TOML}; \
	fi
endef


# Generate rules for all scripts and chains
# e.g. DeployLPNRegistryV1_mainnet
# NOTE: The evm_version is automatically changed to `shanghai` for *_mantle Makefile scripts because mantle does not support `cancun` yet
define make-command-rule
$(1)_$(2): CHAIN_FLAGS = $(call get-chain-flags,$(2))
$(1)_$(2): DEPLOYER_FLAGS = $(call use-mainnet-deployer,$(2))
$(1)_$(2):
	$(if $(filter mantle%,$(2)),$(call switch-evm-version),)
	CHAIN_ALIAS=$(2) forge script $(1) --rpc-url $(2) $${DEPLOY_FLAGS} $${CHAIN_FLAGS} $${DEPLOYER_FLAGS} $(ARGS)
	$(if $(filter mantle%,$(2)),$(call restore-evm-version),)
endef

$(foreach chain,${CHAINS},$(foreach script,${SCRIPT_NAMES},$(eval $(call make-command-rule,${script},${chain}))))

.PHONY: test

# Other non-generic rules
install         :; forge install
update          :; forge update
build           :; forge build
test            :; forge test -vvv
coverage        :; forge coverage -v --no-match-coverage "(script|test|examples|v0|mocks)"
coverage-report :; forge coverage -v --no-match-coverage "(script|test|examples|v0|mocks)" --report lcov
clean           :; forge clean
snapshot        :; forge snapshot
fmt             :; forge fmt
slither         :; docker run -ti --entrypoint=/home/ethsec/.local/bin/slither -v ./:/local/ --workdir=/local trailofbits/eth-security-toolbox:nightly .

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

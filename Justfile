[group('build')]
install:
  forge soldeer install

[group('build')]
build:
	forge build

[group('build')]
clean:
	forge clean

[group('build')]
fmt:
	forge fmt

[group('test')]
test:
	forge test -v
	
[group('test')]
coverage:
	forge coverage -v --no-match-coverage "(script|test|mocks)"

[group('test')]
snapshot:
	forge snapshot

[group('test')]
vertigo:
	vertigo run --src-dir src

[group('static-analysis')]
slither:
	forge build --skip */test/** */script/**
	docker run -it \
		--entrypoint=slither \
		--volume ./:/local/ \
		--workdir=/local \
		--platform linux/amd64 \
		trailofbits/eth-security-toolbox:latest . --fail-high --ignore-compile

[group('static-analysis')]
aderyn:
	aderyn; glow report.md; rm report.md

[group('lint')]
lint:
	bun run solhint 'src/**/*.sol' --noPoster

[group('lint')]
lintspec:
	lintspec

[group('deploy')]
check-balances env:
	forge script script/CheckDeploymentKeyBalances.s.sol --sig 'run(string)' {{env}}

[group('deploy')]	
deploy-v2 chain:
	forge script script/deploy/DeployLPNV2Contracts.s.sol \
		--rpc-url {{chain}} \
		--ffi \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--verifier etherscan \
		--delay 10 \
		--broadcast \
		--retries 7

[group('deploy')]	
update-v2-executors chain:
	forge script script/UpdateQueryExecutors.s.sol \
		--ffi \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--verifier etherscan \
		--delay 10 \
		--broadcast \
		--retries 7

[group('deploy')]	
deploy-latoken chain:
	forge script script/deploy/DeployLAToken.s.sol \
		--rpc-url {{chain}} \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--verifier etherscan \
		--delay 10 \
		--retries 7 \
		--broadcast

[group('deploy')]
deploy-la-staker chain:
	forge script script/deploy/DeployLAPublicStaker.s.sol \
		--rpc-url {{chain}} \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--verifier etherscan \
		--delay 10 \
		--retries 7 \
		--broadcast

[group('deploy')]
deploy-la-escrow chain:
	forge script script/deploy/DeployLAEscrow.s.sol \
		--rpc-url {{chain}} \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--verifier etherscan \
		--delay 10 \
		--retries 7 \
		--broadcast

[group('docs')]
generate-docs:
	bun surya mdreport docs/coprocessor/SuryaReport.md src/v2/**/*.sol --title-deepness 1
	bun surya mdreport docs/latoken/SuryaReport.md src/latoken/*.sol --title-deepness 1
	bun surya graph src/v2/**/*.sol | dot -Tpng > docs/coprocessor/SuryaGraph.png
	bun sol2uml src/v2/ --hideInterfaces --hideStructs --hideEnums --outputFileName docs/coprocessor/UML.svg
	bun sol2uml src/latoken/ --hideInterfaces --hideStructs --hideEnums --outputFileName docs/latoken/UML.svg

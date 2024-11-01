#! /bin/bash

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
BRANCH=main
VERIFIER_FILE=./src/v1/Groth16Verifier.sol
VERIFIER_EXTENSIONS_FILE=./src/v1/Groth16VerifierExtensions.sol
VERIFIER_SOL_URL="https://pub-64a4eb6e897e425083647b3e0e8539a1.r2.dev/groth16_assets/verifier.sol"

cd $GIT_REPO_PATH && \
    git fetch origin $BRANCH && \
    git checkout $BRANCH && \
    git pull origin $BRANCH && \
    cd -

wget -O $VERIFIER_FILE $VERIFIER_SOL_URL
cp "${GIT_REPO_PATH}/${CODE_DIR_PATH}/Groth16VerifierExtensions.sol" $VERIFIER_EXTENSIONS_FILE

# Use as library instead of contract
sed -i '' 's/contract Verifier/library Groth16Verifier/' $VERIFIER_FILE

# Use internal instead of public functions
sed -i '' 's/public view/internal view/' $VERIFIER_FILE

# Read proof argument from memory instead of calldata
sed -i '' 's/calldata proof/memory proof/' $VERIFIER_FILE
sed -i '' $'s/calldatacopy(f, proof, 0x100)/mstore(f, mload(add(proof, 0x00)))\
    mstore(add(f, 0x20), mload(add(proof, 0x20)))\
    mstore(add(f, 0x40), mload(add(proof, 0x40)))\
    mstore(add(f, 0x60), mload(add(proof, 0x60)))\
    mstore(add(f, 0x80), mload(add(proof, 0x80)))\
    mstore(add(f, 0xa0), mload(add(proof, 0xa0)))\
    mstore(add(f, 0xc0), mload(add(proof, 0xc0)))\
    mstore(add(f, 0xe0), mload(add(proof, 0xe0)))/' $VERIFIER_FILE

# Read input argument from memory instead of calldata
sed -i '' 's/calldata input/memory input/' $VERIFIER_FILE
sed -i '' 's/calldataload(input)/mload(input)/' $VERIFIER_FILE
sed -i '' 's/calldataload(add(input, 32))/mload(add(input, 32))/' $VERIFIER_FILE
sed -i '' 's/calldataload(add(input, 64))/mload(add(input, 64))/' $VERIFIER_FILE

# Import verifier library with renamed filename
sed -i '' 's/import {Verifier} from ".\/verifier.sol";/import {Groth16Verifier} from ".\/Groth16Verifier.sol";\
   import {isCDK} from "..\/utils\/Constants.sol";/' $VERIFIER_EXTENSIONS_FILE

# Use extensions as library instead of contract
sed -i '' 's/contract Query is Verifier {/library Groth16VerifierExtensions {/' $VERIFIER_EXTENSIONS_FILE
sed -i '' 's/CIRCUIT_DIGEST/Groth16Verifier.CIRCUIT_DIGEST/' $VERIFIER_EXTENSIONS_FILE
sed -i '' 's/this.verifyProof/Groth16Verifier.verifyProof/' $VERIFIER_EXTENSIONS_FILE

# Use internal instead of public functions
sed -i '' 's/public view/internal view/' $VERIFIER_EXTENSIONS_FILE

# Patch `verifyQuery` function to be `view` instead of `pure`
sed -i '' '/function verifyQuery.*/,+2 s/pure/view/' $VERIFIER_EXTENSIONS_FILE

# Patch `verifyQuery` function to skip blockhash verification for polygon CDK chains
sed -i '' 's/blockHash == query.blockHash/isCDK() || blockHash == query.blockHash/' $VERIFIER_EXTENSIONS_FILE

forge fmt

# verifyProof
    # calldatacopy(f, proof, 0x100)
    # ===>
    # mstore(f, mload(add(proof, 0x00)))
    # mstore(add(f, 0x20), mload(add(proof, 0x20)))
    # mstore(add(f, 0x40), mload(add(proof, 0x40)))
    # mstore(add(f, 0x60), mload(add(proof, 0x60)))
    # mstore(add(f, 0x80), mload(add(proof, 0x80)))
    # mstore(add(f, 0xa0), mload(add(proof, 0xa0)))
    # mstore(add(f, 0xc0), mload(add(proof, 0xc0)))
    # mstore(add(f, 0xe0), mload(add(proof, 0xe0)))

# publicInputMSM
    # s := calldataload(input)
    # ===>
    # s := mload(input)

    # s := calldataload(add(input, 32))
    # ===>
    # s := mload(add(input, 32))

    # s := calldataload(add(input, 64))
    # ===>
    # s := mload(add(input, 64))

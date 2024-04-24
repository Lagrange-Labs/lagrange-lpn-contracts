#! /bin/bash

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
BRANCH=main
VERIFIER_FILE=./src/Groth16Verifier.sol
VERIFIER_EXTENSIONS_FILE=./src/Groth16VerifierExtensions.sol

cd $GIT_REPO_PATH && \
    git fetch origin $BRANCH && \
    git checkout $BRANCH && \
    git pull origin $BRANCH && \
    cd -

cp "${GIT_REPO_PATH}/${CODE_DIR_PATH}/verifier.sol" $VERIFIER_FILE
cp "${GIT_REPO_PATH}/${CODE_DIR_PATH}/query2.sol" $VERIFIER_EXTENSIONS_FILE

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
sed -i '' 's/verifier.sol/Groth16Verifier.sol/' $VERIFIER_EXTENSIONS_FILE

# Use extensions as library instead of contract
sed -i '' 's/contract Query2 is Verifier {/library Groth16VerifierExtensions {/' $VERIFIER_EXTENSIONS_FILE
sed -i '' 's/CIRCUIT_DIGEST/Groth16Verifier.CIRCUIT_DIGEST/' $VERIFIER_EXTENSIONS_FILE
sed -i '' 's/this.verifyProof/Groth16Verifier.verifyProof/' $VERIFIER_EXTENSIONS_FILE

# Use internal instead of public functions
sed -i '' 's/public view/internal view/' $VERIFIER_EXTENSIONS_FILE

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

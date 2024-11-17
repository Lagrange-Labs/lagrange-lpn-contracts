#! /bin/bash

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
ENV=$1
VERIFIER_FOLDER=./script/output/$1
VERIFIER_FILE=$VERIFIER_FOLDER/Groth16Verifier.sol.ignore
VERIFIER_EXTENSIONS_FILE=$VERIFIER_FOLDER/Groth16VerifierExtensions.sol.ignore
#VERIFIER_SOL_URL="https://pub-64a4eb6e897e425083647b3e0e8539a1.r2.dev/groth16_assets/verifier.sol"


case $(uname -s) in
    Linux*)     SED="sed -i";;
    Darwin*)    SED="sed -i ''";;
    *)          echo "Unknown OS; please adapt the sed selection process"; exit 1;;
esac

case "$ENV" in
  dev-0)
    VERIFIER_SOL_URL="https://pub-64a4eb6e897e425083647b3e0e8539a1.r2.dev"
    BRANCH=holesky
    ;;
  dev-1)
    VERIFIER_SOL_URL="https://pub-a894572689a54c008859f232868fc67d.r2.dev"
    BRANCH=holesky
    ;;
  dev-3)
    VERIFIER_SOL_URL="https://pub-bca6985bd0e849b5b8840edc0b7f9e15.r2.dev"
    BRANCH=holesky
    ;;
  test)
    VERIFIER_SOL_URL="https://pub-fbb5db8dc9ee4e8da9daf13e07d27c24.r2.dev"
    BRANCH=holesky
    ;;
  *)
    echo "Usage: $0 {dev-x|test}"
    exit 1
    ;;
esac

echo "VERIFIER_SOL_URL: $VERIFIER_SOL_URL"

VERIFIER_SOL_URL="$VERIFIER_SOL_URL/groth16_assets/verifier.sol"

cd $GIT_REPO_PATH && \
    git fetch origin $BRANCH && \
    git checkout $BRANCH && \
    git pull origin $BRANCH && \
    cd -

mkdir -p $VERIFIER_FOLDER

wget -O $VERIFIER_FILE $VERIFIER_SOL_URL
cp "${GIT_REPO_PATH}/${CODE_DIR_PATH}/Groth16VerifierExtensions.sol" $VERIFIER_EXTENSIONS_FILE

# Use as library instead of contract
$SED 's/contract Verifier/library Groth16Verifier/' $VERIFIER_FILE

# Use internal instead of public functions
$SED 's/public view/internal view/' $VERIFIER_FILE

# Read proof argument from memory instead of calldata
$SED 's/calldata proof/memory proof/' $VERIFIER_FILE
$SED $'s/calldatacopy(f, proof, 0x100)/mstore(f, mload(add(proof, 0x00)))\
    mstore(add(f, 0x20), mload(add(proof, 0x20)))\
    mstore(add(f, 0x40), mload(add(proof, 0x40)))\
    mstore(add(f, 0x60), mload(add(proof, 0x60)))\
    mstore(add(f, 0x80), mload(add(proof, 0x80)))\
    mstore(add(f, 0xa0), mload(add(proof, 0xa0)))\
    mstore(add(f, 0xc0), mload(add(proof, 0xc0)))\
    mstore(add(f, 0xe0), mload(add(proof, 0xe0)))/' $VERIFIER_FILE

# Read input argument from memory instead of calldata
$SED 's/calldata input/memory input/' $VERIFIER_FILE
$SED 's/calldataload(input)/mload(input)/' $VERIFIER_FILE
$SED 's/calldataload(add(input, 32))/mload(add(input, 32))/' $VERIFIER_FILE
$SED 's/calldataload(add(input, 64))/mload(add(input, 64))/' $VERIFIER_FILE

# Import verifier library with renamed filename
$SED 's/import {Verifier} from ".\/verifier.sol";/import {Groth16Verifier} from ".\/Groth16Verifier.sol";\
   import {isCDK} from "..\/utils\/Constants.sol";/' $VERIFIER_EXTENSIONS_FILE

# Use extensions as library instead of contract
$SED 's/contract Query is Verifier {/library Groth16VerifierExtensions {/' $VERIFIER_EXTENSIONS_FILE
$SED 's/CIRCUIT_DIGEST/Groth16Verifier.CIRCUIT_DIGEST/' $VERIFIER_EXTENSIONS_FILE
$SED 's/this.verifyProof/Groth16Verifier.verifyProof/' $VERIFIER_EXTENSIONS_FILE

# Use internal instead of public functions
$SED 's/public view/internal view/' $VERIFIER_EXTENSIONS_FILE

# Patch `verifyQuery` function to be `view` instead of `pure`
$SED '/function verifyQuery.*/,+2 s/pure/view/' $VERIFIER_EXTENSIONS_FILE

# Patch `verifyQuery` function to skip blockhash verification for polygon CDK chains
$SED 's/blockHash == query.blockHash/isCDK() || blockHash == query.blockHash/' $VERIFIER_EXTENSIONS_FILE

forge fmt

cp $VERIFIER_EXTENSIONS_FILE ./src/v1/Groth16VerifierExtensions.sol
cp $VERIFIER_FILE ./src/v1/Groth16Verifier.sol

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

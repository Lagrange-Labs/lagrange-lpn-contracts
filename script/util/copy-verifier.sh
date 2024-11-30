#! /bin/bash

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
ENV=$1
VERIFIER_FOLDER=./script/output/$1
VERIFIER_FILE=$VERIFIER_FOLDER/Groth16Verifier.sol
VERIFIER_EXTENSIONS_FILE=$VERIFIER_FOLDER/Groth16VerifierExtensions.sol
#VERIFIER_SOL_URL="https://pub-64a4eb6e897e425083647b3e0e8539a1.r2.dev/groth16_assets/verifier.sol"


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

# Use awk for the following transformations
awk '{
  # Use as library instead of contract
  gsub(/contract Verifier/, "library Groth16Verifier");

  # Use internal instead of public functions
  gsub(/public view/, "internal view");

  # Read proof argument from memory instead of calldata
  gsub(/calldata proof/, "memory proof");
  gsub(/calldatacopy\(f, proof, 0x100\)/, "mstore(f, mload(add(proof, 0x00)))\nmstore(add(f, 0x20), mload(add(proof, 0x20)))\nmstore(add(f, 0x40), mload(add(proof, 0x40)))\nmstore(add(f, 0x60), mload(add(proof, 0x60)))\nmstore(add(f, 0x80), mload(add(proof, 0x80)))\nmstore(add(f, 0xa0), mload(add(proof, 0xa0)))\nmstore(add(f, 0xc0), mload(add(proof, 0xc0)))\nmstore(add(f, 0xe0), mload(add(proof, 0xe0)))");

  # Read input argument from memory instead of calldata
  gsub(/calldata input/, "memory input");
  gsub(/calldataload\(input\)/, "mload(input)");
  gsub(/calldataload\(add\(input, 32\)\)/, "mload(add(input, 32))");
  gsub(/calldataload\(add\(input, 64\)\)/, "mload(add(input, 64))");

  print;
}' $VERIFIER_FILE > $VERIFIER_FILE.tmp && mv $VERIFIER_FILE.tmp $VERIFIER_FILE

awk '{
  # Import verifier library with renamed filename
  gsub(/import {Verifier} from ".\/verifier.sol";/, "import {Groth16Verifier} from \".\/Groth16Verifier.sol\";\n   import {isCDK} from \"..\/utils\/Constants.sol\";");

  # Use extensions as library instead of contract
  gsub(/contract Query is Verifier {/, "library Groth16VerifierExtensions {");
  gsub(/CIRCUIT_DIGEST/, "Groth16Verifier.CIRCUIT_DIGEST");
  gsub(/this.verifyProof/, "Groth16Verifier.verifyProof");

  # Use internal instead of public functions
  gsub(/public view/, "internal view");

  # Change "view" to "pure" in "function verifyQuery"
  if (match($0, /function verifyQuery.*/)) {
    sub(/pure/, "view"); 
  }

  # Patch `verifyQuery` function to skip blockhash verification for polygon CDK chains
  gsub(/blockHash == query.blockHash/, "isCDK() || blockHash == query.blockHash");

  print;
}' $VERIFIER_EXTENSIONS_FILE > $VERIFIER_EXTENSIONS_FILE.tmp && mv $VERIFIER_EXTENSIONS_FILE.tmp $VERIFIER_EXTENSIONS_FILE



forge fmt

cp $VERIFIER_EXTENSIONS_FILE ./src/v1/Groth16VerifierExtensions.sol
cp $VERIFIER_FILE ./src/v1/Groth16Verifier.sol

mv $VERIFIER_EXTENSIONS_FILE $VERIFIER_EXTENSIONS_FILE.ignore
mv $VERIFIER_FILE $VERIFIER_FILE.ignore
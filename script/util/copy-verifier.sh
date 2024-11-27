#! /bin/bash
set -e

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
ENV=$1
VERIFIER_FOLDER=./script/output/$1
VERIFIER_FILE=$VERIFIER_FOLDER/Verifier.sol.ignore
VERIFIER_EXTENSION_FILE=$VERIFIER_FOLDER/Groth16VerifierExtension.sol.ignore
VERIFIER_EXTENSION_URL=https://raw.githubusercontent.com/Lagrange-Labs/mapreduce-plonky2/refs/heads/main/groth16-framework/test_data/Groth16VerifierExtension.sol

case "$ENV" in
  dev-0)
    VERIFIER_SOL_URL="https://pub-64a4eb6e897e425083647b3e0e8539a1.r2.dev"
    ;;
  dev-1)
    VERIFIER_SOL_URL="https://pub-a894572689a54c008859f232868fc67d.r2.dev"
    ;;
  dev-3)
    VERIFIER_SOL_URL="https://pub-bca6985bd0e849b5b8840edc0b7f9e15.r2.dev"
    ;;
  test)
    VERIFIER_SOL_URL="https://pub-fbb5db8dc9ee4e8da9daf13e07d27c24.r2.dev"
    ;;
  *)
    echo "Usage: $0 {dev-x|test}"
    exit 1
    ;;
esac

VERIFIER_SOL_URL="$VERIFIER_SOL_URL/groth16_assets/verifier.sol"

mkdir -p $VERIFIER_FOLDER

wget -O $VERIFIER_FILE $VERIFIER_SOL_URL
wget -O $VERIFIER_EXTENSION_FILE $VERIFIER_EXTENSION_URL

# TODO - remove all manual transformations... so close!
awk '{
  # Import verifier library with renamed filename
  gsub(/import {Verifier} from ".\/Verifier.sol";/, "import {Verifier} from \".\/Verifier.sol\";\n   import {isCDK} from \"..\/utils\/Constants.sol\";");

  # Patch `verifyQuery` function to skip blockhash verification for polygon CDK chains
  gsub(/blockHash == expectedBlockHash/, "isCDK\(\) || blockHash == expectedBlockHash");

  print;
}' $VERIFIER_EXTENSION_FILE > $VERIFIER_EXTENSION_FILE.tmp && mv $VERIFIER_EXTENSION_FILE.tmp $VERIFIER_EXTENSION_FILE

cp $VERIFIER_EXTENSION_FILE ./src/v1/Groth16VerifierExtension.sol
cp $VERIFIER_FILE ./src/v1/Verifier.sol

forge fmt

#! /bin/bash
set -e

# redirect stderr to stdout, this prevents foundry from erroring when calling this script directly
exec 2>&1

GIT_REPO_PATH=../mapreduce-plonky2
CODE_DIR_PATH=groth16-framework/test_data
ENV=$1
VERIFIER_EXTENSION_URL=https://raw.githubusercontent.com/Lagrange-Labs/mapreduce-plonky2/refs/heads/main/groth16-framework/test_data/Groth16VerifierExtension.sol

# NOTE: all dev-x environments are deployed to holesky. The "holesky" environment is a "test" environment, like the other chains.
case "$ENV" in
  dev-0)
    VERIFIER_SOL_URL="https://pub-d7c7f0d6979a41f2b25137eaecf12d7b.r2.dev/1"
    ENV_FOLDER_NAME="dev-0"
    ;;
  dev-1)
    VERIFIER_SOL_URL="https://pub-d7c7f0d6979a41f2b25137eaecf12d7b.r2.dev/1"
    ENV_FOLDER_NAME="dev-1"
    ;;
  dev-3)
    VERIFIER_SOL_URL="https://pub-d7c7f0d6979a41f2b25137eaecf12d7b.r2.dev/1"
    ENV_FOLDER_NAME="dev-3"
    ;;
  test)
    VERIFIER_SOL_URL="https://pub-d7c7f0d6979a41f2b25137eaecf12d7b.r2.dev/1"
    ENV_FOLDER_NAME="test"
    ;;
  prod)
    VERIFIER_SOL_URL="https://pub-d7c7f0d6979a41f2b25137eaecf12d7b.r2.dev/1"
    ENV_FOLDER_NAME="prod"
    ;;
  *)
    echo "Usage: $0 {env|chain-name}"
    exit 1
    ;;
esac

VERIFIER_SOL_URL="$VERIFIER_SOL_URL/groth16_assets/Verifier.sol"
VERIFIER_FOLDER="./script/output/$ENV_FOLDER_NAME"
VERIFIER_FILE=$VERIFIER_FOLDER/Verifier.sol.ignore
VERIFIER_EXTENSION_FILE=$VERIFIER_FOLDER/Groth16VerifierExtension.sol.ignore

mkdir -p $VERIFIER_FOLDER

# TODO - once all environments have upgraded to latest MRP2, we will no longer need to support
# both Verifier.sol and verifier.sol and can standardize on the uppercase version.
wget -O $VERIFIER_FILE $VERIFIER_SOL_URL || {
    # If it fails, try with lowercase v
    echo "Failed to download Verifier.sol, falling back to verifier.sol"
    VERIFIER_SOL_URL="${VERIFIER_SOL_URL/Verifier.sol/verifier.sol}"
    wget -O $VERIFIER_FILE $VERIFIER_SOL_URL
}
wget -O $VERIFIER_EXTENSION_FILE $VERIFIER_EXTENSION_URL

cp $VERIFIER_EXTENSION_FILE ./src/v1/Groth16VerifierExtension.sol
cp $VERIFIER_FILE ./src/v1/Verifier.sol
cp $VERIFIER_EXTENSION_FILE ./src/v2/Groth16VerifierExtension.sol
cp $VERIFIER_FILE ./src/v2/Verifier.sol

forge fmt

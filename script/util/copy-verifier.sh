#! /bin/bash
set -e

# redirect stderr to stdout, this prevents foundry from erroring when calling this script directly
exec 2>&1

# get command line arguments
ENV=$1
PP_VERSION=$2

# validate arguments
if [ -z "$ENV" ] || [ -z "$PP_VERSION" ]; then
    echo "Error: ENV and PP_VERSION are required"
    echo "Usage: $0 <ENV> <PP_VERSION>"
    exit 1
fi

# validate environment
if [[ "$ENV" != "dev-0" && "$ENV" != "dev-1" && "$ENV" != "dev-2" && "$ENV" != "dev-3" && "$ENV" != "test" && "$ENV" != "prod" ]]; then
    echo "Error: Invalid environment. Must be one of: dev-X, test, or prod"
    exit 1
fi

VERIFIER_SOL_URL="https://public-parameters.distributed-query.io/$PP_VERSION/groth16_assets/Verifier.sol"
VERIFIER_FOLDER="./script/output/$ENV"
VERIFIER_FILE=$VERIFIER_FOLDER/Verifier.sol.ignore
VERIFIER_EXTENSION_FILE=$VERIFIER_FOLDER/Groth16VerifierExtension.sol.ignore

mkdir -p $VERIFIER_FOLDER

wget -O $VERIFIER_FILE $VERIFIER_SOL_URL
wget -O $VERIFIER_EXTENSION_FILE https://raw.githubusercontent.com/Lagrange-Labs/mapreduce-plonky2/refs/heads/main/groth16-framework/test_data/Groth16VerifierExtension.sol

cp $VERIFIER_EXTENSION_FILE ./src/v1/Groth16VerifierExtension.sol
cp $VERIFIER_FILE ./src/v1/Verifier.sol
cp $VERIFIER_EXTENSION_FILE ./src/v2/Groth16VerifierExtension.sol
cp $VERIFIER_FILE ./src/v2/Verifier.sol

forge fmt

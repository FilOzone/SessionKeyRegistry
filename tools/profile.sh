#!/bin/bash

set -e

pushd ../localnet
bash ./reset.sh
source ./local_lotus.sh
popd

TOKEN_ADDRESS=0xe9ae74e0c182aab11bddb483227cc1f6600b3625
RAIL_ADDRESS=0xf6990c51dc94b36c5d5184bf60107efe99dde592

forge script -vvv -g 44000 --broadcast --chain-id $CHAIN_ID --sender $SENDER_ADDRESS --private-key $SENDER_KEY --rpc-url $API_URL/rpc/v1 --sig "run()" tools/Profile.s.sol:Profile
[[ "$(../forge-script-gas-report/forge_script_block_numbers ./broadcast/Profile.s.sol/$CHAIN_ID/run-latest.json | wc -l)" -eq 1 ]] || (echo possible nondeterminism detected && exit 1)
../forge-script-gas-report/forge_script_gas_report ./broadcast/Profile.s.sol/$CHAIN_ID/run-latest.json | tee .gas-profile

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseDeployer} from "../BaseDeployer.s.sol";

/// @dev Add new multisig signers and update signing threshold
/// @dev Can execute this script like so:
/// make AddMultisigSigners_base ARGS='--sig "run(address[],uint256)" "[0x4fbCd47f4f9c28645F6E70C9c7C2ca41A6Ed6727,0xa2DAF7E5F433f12461D07FF0495fE3694D6B483F]" 2'
contract AddMultisigSigners is BaseDeployer {
    function run(address[] memory additionalSigners, uint256 newThreshold)
        public
        isBatch(address(SAFE))
    {
        for (uint256 i = 0; i < additionalSigners.length; i++) {
            bytes memory txn = abi.encodeWithSelector(
                SAFE.addOwnerWithThreshold.selector,
                additionalSigners[i],
                newThreshold
            );
            addToBatch(address(SAFE), 0, txn);
        }

        executeBatch(true);
    }
}

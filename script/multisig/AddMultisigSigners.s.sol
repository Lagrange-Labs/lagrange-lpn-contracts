// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BatchScript} from "forge-safe/BatchScript.sol";

interface ISafe {
    /**
     * @notice Adds the owner `owner` to the Safe and updates the threshold to `_threshold`.
     * @dev This can only be done via a Safe transaction.
     * @param owner New owner address.
     * @param _threshold New threshold.
     */
    function addOwnerWithThreshold(address owner, uint256 _threshold)
        external;
}

/// @dev Deploy multsigs with the same address (0xE7cdA508FEB53713fB7C69bb891530C924980366)
/// to various EVM chains (except for zkSync !)

/// @dev Can execute this script like so:
/// make AddMultisigSigners_base ARGS='--sig "run(address[],uint256)" "[0x4fbCd47f4f9c28645F6E70C9c7C2ca41A6Ed6727,0xa2DAF7E5F433f12461D07FF0495fE3694D6B483F]" 2'
contract AddMultisigSigners is BatchScript {
    ISafe SAFE = ISafe(0xE7cdA508FEB53713fB7C69bb891530C924980366);

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

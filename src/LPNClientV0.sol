// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract LPNClientV0 {
    function lpnCallback(uint256 requestId, uint256 result) external virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AirdropableUpgradable} from "./AirdropableUpgradable.sol";
import {OFTCustomUpgradeable} from
    "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCustomUpgradeable.sol";
import {OnlyLZAdmin} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/OnlyLZAdmin.sol";

/// @title AirdropableOFTUpgradable
/// @dev Implementation of the LZ OFT standard with airdrop and minting functionality
abstract contract AirdropableOFTUpgradable is
    AirdropableUpgradable,
    OFTCustomUpgradeable
{
    uint8 internal constant DECIMALS = 18;

    /// @notice Constructor for the AirdropableOFTUpgradable contract
    /// @param lzEndpoint The endpoint for the LayerZero protocol
    constructor(address lzEndpoint)
        OFTCustomUpgradeable(DECIMALS, lzEndpoint)
    {}

    /// @inheritdoc OnlyLZAdmin
    modifier onlyLZAdmin() override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    /// @inheritdoc OFTCustomUpgradeable
    function _oftBurn(address _from, uint256 _amountLD)
        internal
        virtual
        override
    {
        _burn(_from, _amountLD);
    }

    /// @inheritdoc OFTCustomUpgradeable
    function _oftMint(address _to, uint256 _amountLD)
        internal
        virtual
        override
    {
        _mint(_to, _amountLD);
    }
}

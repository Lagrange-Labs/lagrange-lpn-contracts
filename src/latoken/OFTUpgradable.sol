// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OFTCustomUpgradeable} from
    "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCustomUpgradeable.sol";
import {OnlyLZAdmin} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/OnlyLZAdmin.sol";

/// @title OFTUpgradable
/// @dev Implementation of the LZ OFT standard with airdrop and minting functionality
abstract contract OFTUpgradable is
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20PermitUpgradeable,
    OFTCustomUpgradeable
{
    /// @notice Constructor for the OFTUpgradable contract
    /// @param lzEndpoint The endpoint for the LayerZero protocol
    constructor(address lzEndpoint)
        OFTCustomUpgradeable(decimals(), lzEndpoint)
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AirdropableUpgradable} from "./AirdropableUpgradable.sol";
import {OFTCustomUpgradeable} from
    "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCustomUpgradeable.sol";

abstract contract AirdropableOFTUpgradable is
    AirdropableUpgradable,
    OFTCustomUpgradeable
{
    constructor(address lzEndpoint) OFTCustomUpgradeable(18, lzEndpoint) {}

    modifier onlyLZAdmin() override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    function _oftBurn(address _from, uint256 _amountLD)
        internal
        virtual
        override
    {
        _burn(_from, _amountLD);
    }

    function _oftMint(address _to, uint256 _amountLD)
        internal
        virtual
        override
    {
        _mint(_to, _amountLD);
    }
}

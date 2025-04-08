// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {OFTUpgradable} from "./OFTUpgradable.sol";
import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/// @title LATokenBase
/// @dev Base contract for the LAToken and LATokenMintable
abstract contract LATokenBase is Initializable, OFTUpgradable {
    string private constant NAME = "Lagrange";
    string private constant SYMBOL = "LA";

    /// @notice Disable initializers on the logic contract
    /// @param lzEndpoint The endpoint for the LayerZero protocol
    constructor(address lzEndpoint) OFTUpgradable(lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initialize the token
    /// @param treasury The address that will be granted the DEFAULT_ADMIN_ROLE
    function __LATokenBase_init(address treasury) internal {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Permit_init(NAME);
        __AccessControlDefaultAdminRules_init(0, treasury);
        __OFT_init(treasury);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlDefaultAdminRulesUpgradeable)
        returns (bool)
    {
        return type(IERC20).interfaceId == interfaceId
            || type(IERC20Permit).interfaceId == interfaceId
            || super.supportsInterface(interfaceId);
    }
}

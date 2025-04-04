// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {AirdropableOFTUpgradable} from "./AirdropableOFTUpgradable.sol";
import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/// @title LAToken
/// @dev Implementation of the upgradable LPN Token with ERC20Permit and AccessControlDefaultAdminRules
contract LAToken is Initializable, AirdropableOFTUpgradable {
    string private constant NAME = "Lagrange";
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Disable initializers on the logic contract
    constructor(address lzEndpoint) AirdropableOFTUpgradable(lzEndpoint) {
        _disableInitializers();
    }

    /// @dev Initializes the token with name, symbol, and roles
    /// @param defaultAdmin The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param minter The address that will be granted the MINTER_ROLE
    function initialize(
        address defaultAdmin,
        address minter,
        bytes32 merkleRoot
    ) public initializer {
        __ERC20_init(NAME, "LA");
        __ERC20Permit_init(NAME);
        __AccessControlDefaultAdminRules_init(0, defaultAdmin);

        _grantRole(MINTER_ROLE, minter);

        if (merkleRoot != bytes32(0)) {
            _setMerkleRoot(merkleRoot);
        }
    }

    /// @notice Mints tokens to a specified address
    /// @param to The address to mint the tokens to
    /// @param amount The amount of tokens to mint
    /// @dev Caller must have the MINTER_ROLE
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
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

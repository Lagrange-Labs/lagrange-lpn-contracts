// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {OFTUpgradable} from "./OFTUpgradable.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/// @title LATokenBase
/// @dev Base contract for the LAToken and LATokenMintable
abstract contract LATokenBase is Initializable, OFTUpgradable {
    /// @dev The peer address and endpoint ID for a peer contract
    struct Peer {
        uint32 endpointID;
        bytes32 peerAddress;
    }

    string private constant NAME = "Lagrange";
    string private constant SYMBOL = "LA";

    error NoTreasuryDeployed();
    error InvalidPeer(uint32 endpointID, bytes32 peerAddress);

    /// @notice Disable initializers on the logic contract
    /// @param lzEndpoint The endpoint for the LayerZero protocol
    constructor(address lzEndpoint) OFTUpgradable(lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initialize the token
    /// @param treasury The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param peers The OFT peers that will be added to the token
    function __LATokenBase_init(address treasury, Peer[] calldata peers)
        internal
    {
        if (treasury.code.length == 0) {
            revert NoTreasuryDeployed();
        }
        __ERC20_init(NAME, SYMBOL);
        __ERC20Permit_init(NAME);
        __AccessControlDefaultAdminRules_init(0, treasury);
        __OFT_init(treasury);
        for (uint256 i = 0; i < peers.length; i++) {
            if (peers[i].endpointID == 0 || peers[i].peerAddress == bytes32(0))
            {
                revert InvalidPeer(peers[i].endpointID, peers[i].peerAddress);
            }
            setPeer(peers[i].endpointID, peers[i].peerAddress);
        }
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

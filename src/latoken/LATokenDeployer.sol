// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LAToken} from "./LAToken.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title LATokenDeployer
/// @notice Deploys and configures the standard LA token with a proxy in a single transaction
/// @dev This is for deploying the non-mintable version of the LA token
contract LATokenDeployer {
    event TokenDeployed(address tokenProxy, address tokenImplementation);

    /// @notice Reverts when a zero address is provided
    error ZeroAddress();

    /// @notice Deploys and configures the standard LA token with a proxy
    /// @param adminMultisig The admin multisig address for token governance
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param peers The OFT peers for the token
    constructor(
        address adminMultisig,
        address lzEndpoint,
        LAToken.Peer[] memory peers
    ) {
        if (adminMultisig == address(0) || lzEndpoint == address(0)) {
            revert ZeroAddress();
        }

        // Deploy standard LAToken implementation
        LAToken tokenStandardImpl = new LAToken(lzEndpoint);
        address tokenImpl = address(tokenStandardImpl);

        // Deploy proxy and initialize LAToken
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            tokenImpl,
            adminMultisig,
            abi.encodeWithSelector(
                LAToken.initialize.selector, adminMultisig, peers
            )
        );
        address tokenProxy = address(proxy);

        emit TokenDeployed(tokenProxy, tokenImpl);
    }
}

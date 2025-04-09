// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LATokenMintable} from "./LATokenMintable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title LATokenMintableDeployer
/// @notice Deploys and configures the mintable LA token with a proxy in a single transaction
/// @dev This is for deploying the mintable version of the LA token with inflation support
contract LATokenMintableDeployer {
    event TokenDeployed(address tokenProxy, address tokenImplementation);

    /// @notice Reverts when a zero address is provided
    error ZeroAddress();

    /// @notice Deploys and configures the mintable LA token with a proxy
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param initialMintHandler The address to receive the initial mint
    /// @param treasury The address that will be granted the MINTER_ROLE
    constructor(
        uint256 inflationRate,
        uint256 initialSupply,
        address lzEndpoint,
        address initialMintHandler,
        address treasury,
        LATokenMintable.Peer[] memory peers
    ) {
        if (
            lzEndpoint == address(0) || treasury == address(0)
                || initialMintHandler == address(0)
        ) {
            revert ZeroAddress();
        }

        // Deploy LATokenMintable implementation
        LATokenMintable tokenMintableImpl =
            new LATokenMintable(lzEndpoint, inflationRate, initialSupply);
        address tokenImpl = address(tokenMintableImpl);

        // Deploy proxy and initialize LATokenMintable
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            tokenImpl,
            treasury,
            abi.encodeWithSelector(
                LATokenMintable.initialize.selector,
                treasury,
                initialMintHandler,
                peers
            )
        );
        address tokenProxy = address(proxy);

        emit TokenDeployed(tokenProxy, tokenImpl);
    }
}

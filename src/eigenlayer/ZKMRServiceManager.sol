// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IAVSDirectory} from
    "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableWhitelist} from "../utils/OwnableWhitelist.sol";
import {IZKMRStakeRegistry, Quorum} from "./interfaces/IZKMRStakeRegistry.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IServiceManager} from
    "eigenlayer-middleware/src/interfaces/IServiceManager.sol";

/// @title zkMapReduce AVS ServiceManager
/// @author Lagrange Labs
contract ZKMRServiceManager is IServiceManager, Ownable, Initializable {
    IZKMRStakeRegistry public stakeRegistry;
    IAVSDirectory private _avsDirectory;

    /// @dev Reserves storage slots for future upgrades
    uint256[50] private __gap;

    /// @notice when applied to a function, only allows the ZKMRStakeRegistry to call it
    modifier onlyStakeRegistry() {
        if (msg.sender != address(stakeRegistry)) {
            revert NotAuthorized();
        }
        _;
    }

    function initialize(
        IAVSDirectory avsDirectory_,
        IZKMRStakeRegistry stakeRegistry_,
        address owner_
    ) public initializer {
        _avsDirectory = avsDirectory_;
        stakeRegistry = stakeRegistry_;

        _initializeOwner(owner_);
    }

    function updateAVSMetadataURI(string memory _metadataURI)
        public
        virtual
        onlyOwner
    {
        _avsDirectory.updateAVSMetadataURI(_metadataURI);
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external onlyStakeRegistry {
        _avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }

    function deregisterOperatorFromAVS(address operator)
        external
        onlyStakeRegistry
    {
        _avsDirectory.deregisterOperatorFromAVS(operator);
    }

    function getRestakeableStrategies()
        external
        view
        returns (address[] memory)
    {
        return _getRestakeableStrategies();
    }

    function getOperatorRestakedStrategies(address)
        external
        view
        returns (address[] memory)
    {
        return _getRestakeableStrategies();
    }

    function _getRestakeableStrategies()
        internal
        view
        returns (address[] memory)
    {
        Quorum memory quorum = stakeRegistry.quorum();
        uint256 strategyCount = quorum.strategies.length;
        address[] memory restakedStrategies = new address[](strategyCount);
        for (uint256 i = 0; i < strategyCount; i++) {
            restakedStrategies[i] = address(quorum.strategies[i].strategy);
        }
        return restakedStrategies;
    }

    function avsDirectory() external view returns (address) {
        return address(_avsDirectory);
    }
}

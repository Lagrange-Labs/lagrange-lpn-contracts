// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from
    "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

struct StrategyParams {
    IStrategy strategy; // The strategy contract reference
    uint96 multiplier; // The multiplier applied to the strategy
}

struct Quorum {
    StrategyParams[] strategies; // An array of strategy parameters to define the quorum
}

struct G1Point {
    uint256 x;
    uint256 y;
}

interface IZKMRStakeRegistry {
    /// @notice Emitted when the system registers an operator
    /// @param _operator The address of the registered operator
    /// @param _avs The address of the associated AVS
    /// @param _publicKey The ECDSA public key used only for the zkmr AVS
    event OperatorRegistered(
        address indexed _operator, address indexed _avs, G1Point _publicKey
    );

    /// @notice Emitted when the system deregisters an operator
    /// @param _operator The address of the deregistered operator
    /// @param _avs The address of the associated AVS
    event OperatorDeregistered(address indexed _operator, address indexed _avs);

    /// @notice Emitted when the system updates the quorum
    /// @param _old The previous quorum configuration
    /// @param _new The new quorum configuration
    event QuorumUpdated(Quorum _old, Quorum _new);

    /// @notice Emitted when the weight to join the operator set updates
    /// @param _old The previous minimum weight
    /// @param _new The new minimumWeight
    event MinimumWeightUpdated(uint256 _old, uint256 _new);

    /// @notice Indicates encountering an invalid signature.
    error InvalidSignature();

    /// @notice Indicates the quorum is invalid
    error InvalidQuorum();

    /// @notice Indicates the system finds a list of items unsorted
    error NotSorted();

    /// @notice Thrown when registering an already registered operator
    error OperatorAlreadyRegistered();

    /// @notice Thrown when de-registering or updating the stake for an unregisted operator
    error OperatorNotRegistered();

    /// @notice Retrieves the current stake quorum details.
    /// @return Quorum - The current quorum of strategies and weights
    function quorum() external view returns (Quorum memory);

    /**
     * @notice Updates the quorum configuration
     * @dev Only callable by the contract owner.
     * @param _quorum The new quorum configuration, including strategies and their new weights
     */
    function updateQuorumConfig(Quorum memory _quorum) external;

    /// @notice Registers a new operator using a provided signature
    /// @param publicKey The ECDSA public key used only for the zkmr AVS
    /// @param operatorSignature Contains the operator's signature, salt, and expiry
    function registerOperator(
        G1Point calldata publicKey,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    /// @notice Deregisters an existing operator
    function deregisterOperator() external;

    /// @notice Calculates the current weight of an operator based on their delegated stake in the strategies considered in the quorum
    /// @param _operator The address of the operator.
    /// @return uint256 - The current weight of the operator; returns 0 if below the threshold.
    function getOperatorWeight(address _operator)
        external
        view
        returns (uint256);

    /// @notice Updates the weight an operator must have to join the operator set
    /// @dev Access controlled to the contract owner
    /// @param _newMinimumWeight The new weight an operator must have to join the operator set
    function updateMinimumWeight(uint256 _newMinimumWeight) external;
}

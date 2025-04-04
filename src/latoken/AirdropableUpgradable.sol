// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {MerkleProof} from
    "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title AirdropableUpgradable
/// @dev Abstract contract that implements airdrop functionality
abstract contract AirdropableUpgradable is
    ERC20PermitUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable
{
    // Airdrop state variables
    bool private s_merkleRootImmutable;
    bytes32 private s_merkleRoot;
    mapping(address => bool) private s_hasClaimed;

    // Custom errors
    error MerkleRootNotSet();
    error AlreadyClaimed();
    error InvalidProof();

    event MerkleRootSet(bytes32 merkleRoot);
    event AirdropClaimed(address indexed account, uint256 amount);

    /// @notice Sets the merkle root for the airdrop
    /// @param merkleRoot The merkle root of the airdrop
    /// @dev Only callable by the admin
    function setMerkleRoot(bytes32 merkleRoot)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setMerkleRoot(merkleRoot);
    }

    /// @notice Claims airdrop tokens using a merkle proof
    /// @param amount The amount of tokens to claim
    /// @param proof The merkle proof
    function claimAirdrop(uint256 amount, bytes32[] calldata proof) external {
        if (s_merkleRoot == bytes32(0)) revert MerkleRootNotSet();
        if (s_hasClaimed[msg.sender]) revert AlreadyClaimed();

        // Verify the merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        if (!MerkleProof.verify(proof, s_merkleRoot, leaf)) {
            revert InvalidProof();
        }

        // Mark as claimed and mint tokens
        s_hasClaimed[msg.sender] = true;
        _mint(msg.sender, amount);

        emit AirdropClaimed(msg.sender, amount);
    }

    /// @notice Internal function to set the merkle root
    /// @param merkleRoot The merkle root to set
    /// @dev Can be called in the initializer if the merkle root is known at deployment time
    function _setMerkleRoot(bytes32 merkleRoot) internal {
        s_merkleRoot = merkleRoot;
        emit MerkleRootSet(merkleRoot);
    }

    /// @notice Returns the merkle root
    /// @return root The merkle root
    function getMerkleRoot() public view returns (bytes32) {
        return s_merkleRoot;
    }
}

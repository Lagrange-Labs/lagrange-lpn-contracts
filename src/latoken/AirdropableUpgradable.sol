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
    struct AirdropStorage {
        bytes32 merkleRoot;
        mapping(address => bool) hasClaimed;
    }

    // keccak256(abi.encode(uint256(keccak256("LAToken.storage.AirdropableUpgradable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_SLOT =
        0x70f1366171695f4553dde0f5e5dc0a68a82d82ec8d402c8c63d06c53eda2f100;

    event MerkleRootSet(bytes32 merkleRoot);
    event AirdropClaimed(address indexed account, uint256 amount);

    error MerkleRootNotSet();
    error AlreadyClaimed();
    error InvalidProof();

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
        AirdropStorage storage $ = _getAirdropStorage();
        if ($.merkleRoot == bytes32(0)) revert MerkleRootNotSet();
        if ($.hasClaimed[msg.sender]) revert AlreadyClaimed();

        // Verify the merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        if (!MerkleProof.verify(proof, $.merkleRoot, leaf)) {
            revert InvalidProof();
        }

        // Mark as claimed and mint tokens
        $.hasClaimed[msg.sender] = true;
        _mint(msg.sender, amount);

        emit AirdropClaimed(msg.sender, amount);
    }

    /// @notice Internal function to set the merkle root
    /// @param merkleRoot The merkle root to set
    /// @dev Can be called in the initializer if the merkle root is known at deployment time
    function _setMerkleRoot(bytes32 merkleRoot) internal {
        AirdropStorage storage $ = _getAirdropStorage();
        $.merkleRoot = merkleRoot;
        emit MerkleRootSet(merkleRoot);
    }

    /// @notice Returns the merkle root
    /// @return root The merkle root
    function getMerkleRoot() public view returns (bytes32) {
        return _getAirdropStorage().merkleRoot;
    }

    /// @notice Gets the airdrop storage struct
    /// @return storage_ The airdrop storage struct
    function _getAirdropStorage()
        private
        pure
        returns (AirdropStorage storage storage_)
    {
        bytes32 position = STORAGE_SLOT;
        assembly {
            storage_.slot := position
        }
    }
}

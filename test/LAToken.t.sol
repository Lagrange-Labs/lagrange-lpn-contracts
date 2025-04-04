// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "./v2/BaseTest.t.sol"; // TODO
import {LAToken} from "../src/latoken/LAToken.sol";
import {AirdropableUpgradable} from "../src/latoken/AirdropableUpgradable.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

contract LATokenTest is BaseTest {
    LAToken public implementation;
    LAToken public token;
    address public admin;
    address public minter;
    address public user1;
    address public user2;
    address public user3;
    address public lzEndpoint;
    uint256 public constant INITIAL_MINT_AMOUNT = 1000 ether;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // For ERC20Permit testing
    uint256 privateKey = 0xBEEF;
    address permitUser = vm.addr(privateKey);

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        lzEndpoint = makeMock("lzEndpoint");

        // Mock setDelegate call to LZ endpoint contract, happens in LAToken.initialize
        vm.mockCall(
            lzEndpoint,
            abi.encodeWithSelector(
                ILayerZeroEndpointV2.setDelegate.selector, admin
            ),
            ""
        );

        // Deploy implementation
        implementation = new LAToken(lzEndpoint);

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            LAToken.initialize.selector, admin, minter, bytes32(0)
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation), admin, initData
        );

        // Get token instance pointing to the proxy
        token = LAToken(address(proxy));

        // Mint initial tokens to user1
        vm.prank(minter);
        token.mint(user1, INITIAL_MINT_AMOUNT);
    }

    function test_Initialize_Success() public view {
        assertEq(token.name(), "Lagrange");
        assertEq(token.symbol(), "LA");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_MINT_AMOUNT);
    }

    function test_Initialize_WithMerkleRoot_Success() public {
        bytes32 merkleRoot = randomBytes32();
        LAToken newImplementation = new LAToken(lzEndpoint);

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            LAToken.initialize.selector, admin, minter, merkleRoot
        );
        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(
            address(newImplementation), admin, initData
        );

        LAToken newToken = LAToken(address(newProxy));

        assertEq(newToken.getMerkleRoot(), merkleRoot);
    }

    function test_Initialize_RevertsWhen_CalledAgain() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        token.initialize(admin, minter, bytes32(0));
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        implementation.initialize(admin, minter, bytes32(0));
    }

    function test_Transfer_Success() public {
        uint256 transferAmount = 100 ether;

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user1), INITIAL_MINT_AMOUNT - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function test_ApproveAndTransferFrom_Success() public {
        uint256 approveAmount = 150 ether;

        vm.prank(user1);
        token.approve(user2, approveAmount);
        assertEq(token.allowance(user1, user2), approveAmount);

        uint256 transferAmount = 100 ether;
        vm.prank(user2);
        token.transferFrom(user1, user2, transferAmount);

        assertEq(token.balanceOf(user1), INITIAL_MINT_AMOUNT - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(user1, user2), approveAmount - transferAmount);
    }

    function test_Mint_Success() public {
        uint256 mintAmount = 500 ether;

        vm.prank(minter);
        token.mint(user2, mintAmount);

        assertEq(token.balanceOf(user2), mintAmount);
        assertEq(token.totalSupply(), INITIAL_MINT_AMOUNT + mintAmount);
    }

    function test_Mint_RevertsWhen_CallerLacksMinterRole() public {
        uint256 mintAmount = 500 ether;

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                MINTER_ROLE
            )
        );
        token.mint(user2, mintAmount);
    }

    function test_Permit_Success() public {
        uint256 permitAmount = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Mint some tokens to the permitUser
        vm.prank(minter);
        token.mint(permitUser, INITIAL_MINT_AMOUNT);

        // Generate permit signature
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                permitTypehash,
                permitUser,
                user1,
                permitAmount,
                token.nonces(permitUser),
                deadline
            )
        );

        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Execute permit
        token.permit(permitUser, user1, permitAmount, deadline, v, r, s);

        // Verify approval worked
        assertEq(token.allowance(permitUser, user1), permitAmount);

        // Verify transferFrom works with the permit
        vm.prank(user1);
        token.transferFrom(permitUser, user1, permitAmount);

        assertEq(
            token.balanceOf(permitUser), INITIAL_MINT_AMOUNT - permitAmount
        );
        assertEq(token.balanceOf(user1), INITIAL_MINT_AMOUNT + permitAmount);
    }

    function test_AccessControlRoles_Success() public {
        // Verify roles
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(MINTER_ROLE, minter));

        // Grant minter role to user1
        vm.prank(admin);
        token.grantRole(MINTER_ROLE, user1);

        // Verify user1 can now mint
        vm.prank(user1);
        token.mint(user2, 100 ether);

        // Revoke minter role
        vm.prank(admin);
        token.revokeRole(MINTER_ROLE, user1);

        // Verify user1 can no longer mint
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                MINTER_ROLE
            )
        );
        vm.prank(user1);
        token.mint(user2, 100 ether);
    }

    function test_SupportsInterface_Success() public view {
        // Define known interface IDs for testing
        // ERC165 interfaceId is 0x01ffc9a7
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        // IERC20 doesn't support ERC165, but we can use a computed value for testing
        bytes4 erc20InterfaceId = 0x36372b07;
        // IERC20Permit interfaceId
        bytes4 erc20PermitInterfaceId = 0x9d8ff7da;
        // IAccessControlDefaultAdminRules interfaceId
        bytes4 accessControlDefaultAdminRulesInterfaceId = 0x31498786;

        // Test that the token supports ERC165
        assertTrue(
            token.supportsInterface(erc165InterfaceId), "Should support ERC165"
        );

        // Test that the token supports all specified interfaces
        assertTrue(
            token.supportsInterface(erc20InterfaceId), "Should support IERC20"
        );
        assertTrue(
            token.supportsInterface(erc20PermitInterfaceId),
            "Should support IERC20Permit"
        );
        assertTrue(
            token.supportsInterface(accessControlDefaultAdminRulesInterfaceId),
            "Should support IAccessControlDefaultAdminRules"
        );
    }

    function test_Airdrop_Success() public {
        // Create a merkle tree with some test data
        address[] memory accounts = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;

        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;

        // Create merkle leaves
        bytes32[] memory leaves = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            leaves[i] = keccak256(abi.encodePacked(accounts[i], amounts[i]));
        }

        // Create merkle tree and get root
        bytes32 merkleRoot = _buildMerkleRoot(leaves);

        // Set merkle root
        vm.prank(admin);
        token.setMerkleRoot(merkleRoot);

        // Generate proof for user1
        bytes32[] memory proof = _generateMerkleProof(leaves, 0);

        // Claim airdrop for user1
        vm.prank(user1);
        token.claimAirdrop(amounts[0], proof);

        // Verify claim
        assertEq(token.balanceOf(user1), INITIAL_MINT_AMOUNT + amounts[0]);
    }

    function test_Airdrop_RevertsWhen_AlreadyClaimed() public {
        // Create a merkle tree with test data
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user1, uint256(100 ether)));
        bytes32 merkleRoot = _buildMerkleRoot(leaves);

        // Set merkle root
        vm.prank(admin);
        token.setMerkleRoot(merkleRoot);

        // Generate proof
        bytes32[] memory proof = _generateMerkleProof(leaves, 0);

        // First claim should succeed
        vm.prank(user1);
        token.claimAirdrop(100 ether, proof);

        // Second claim should revert
        vm.prank(user1);
        vm.expectRevert(AirdropableUpgradable.AlreadyClaimed.selector);
        token.claimAirdrop(100 ether, proof);
    }

    function test_Airdrop_RevertsWhen_InvalidProof() public {
        // Create a merkle tree with test data
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user1, uint256(100 ether)));
        bytes32 merkleRoot = _buildMerkleRoot(leaves);

        // Set merkle root
        vm.prank(admin);
        token.setMerkleRoot(merkleRoot);

        // Create invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(0);

        // Claim should revert with invalid proof
        vm.prank(user1);
        vm.expectRevert(AirdropableUpgradable.InvalidProof.selector);
        token.claimAirdrop(100 ether, invalidProof);
    }

    function test_Airdrop_RevertsWhen_MerkleRootNotSet() public {
        // Create a merkle tree with test data
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user1, uint256(100 ether)));
        bytes32[] memory proof = _generateMerkleProof(leaves, 0);

        // Claim should revert when merkle root is not set
        vm.prank(user1);
        vm.expectRevert(AirdropableUpgradable.MerkleRootNotSet.selector);
        token.claimAirdrop(100 ether, proof);
    }

    function test_SetMerkleRoot_Success() public {
        // Assert that the merkle root is not set
        bytes32 merkleRoot = token.getMerkleRoot();
        assertEq(merkleRoot, bytes32(0));

        // Set merkle root
        bytes32 newMerkleRoot = randomBytes32();
        vm.expectEmit();
        emit AirdropableUpgradable.MerkleRootSet(newMerkleRoot);
        vm.prank(admin);
        token.setMerkleRoot(newMerkleRoot);

        // Assert that the merkle root is set
        assertEq(token.getMerkleRoot(), newMerkleRoot);
    }

    function test_SetMerkleRoot_RevertsWhen_NotAdmin() public {
        bytes32 merkleRoot = bytes32(uint256(1));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user1);
        token.setMerkleRoot(merkleRoot);
    }

    // Helper function to build a merkle root from leaves
    function _buildMerkleRoot(bytes32[] memory leaves)
        internal
        pure
        returns (bytes32)
    {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];

        bytes32[] memory hashes = new bytes32[](leaves.length);
        for (uint256 i = 0; i < leaves.length; i++) {
            hashes[i] = leaves[i];
        }

        while (hashes.length > 1) {
            bytes32[] memory newHashes =
                new bytes32[](hashes.length / 2 + (hashes.length % 2));
            for (uint256 i = 0; i < hashes.length; i += 2) {
                if (i + 1 < hashes.length) {
                    // Ensure consistent hashing order - smaller hash goes first
                    if (hashes[i] <= hashes[i + 1]) {
                        newHashes[i / 2] = keccak256(
                            abi.encodePacked(hashes[i], hashes[i + 1])
                        );
                    } else {
                        newHashes[i / 2] = keccak256(
                            abi.encodePacked(hashes[i + 1], hashes[i])
                        );
                    }
                } else {
                    newHashes[i / 2] = hashes[i];
                }
            }
            hashes = newHashes;
        }

        return hashes[0];
    }

    // Helper function to generate a merkle proof
    function _generateMerkleProof(bytes32[] memory leaves, uint256 index)
        internal
        pure
        returns (bytes32[] memory)
    {
        if (leaves.length <= 1) return new bytes32[](0);

        // Calculate the number of proof elements needed
        uint256 proofLength = 0;
        uint256 currentLength = leaves.length;
        while (currentLength > 1) {
            proofLength++;
            currentLength = (currentLength + 1) / 2;
        }

        bytes32[] memory proof = new bytes32[](proofLength);
        uint256 proofIndex = 0;

        // Generate proof elements for each level
        bytes32[] memory currentLevel = leaves;
        uint256 currentIndex = index;

        while (currentLevel.length > 1) {
            uint256 pairIndex = currentIndex ^ 1;
            if (pairIndex < currentLevel.length) {
                // Ensure consistent hashing order - smaller hash goes first
                if (currentLevel[currentIndex] <= currentLevel[pairIndex]) {
                    proof[proofIndex++] = currentLevel[pairIndex];
                } else {
                    proof[proofIndex++] = currentLevel[pairIndex];
                }
            }

            // Move to next level
            bytes32[] memory nextLevel =
                new bytes32[]((currentLevel.length + 1) / 2);
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    // Ensure consistent hashing order - smaller hash goes first
                    if (currentLevel[i] <= currentLevel[i + 1]) {
                        nextLevel[i / 2] = keccak256(
                            abi.encodePacked(
                                currentLevel[i], currentLevel[i + 1]
                            )
                        );
                    } else {
                        nextLevel[i / 2] = keccak256(
                            abi.encodePacked(
                                currentLevel[i + 1], currentLevel[i]
                            )
                        );
                    }
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            currentLevel = nextLevel;
            currentIndex = currentIndex / 2;
        }

        return proof;
    }
}

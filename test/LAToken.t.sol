// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {LAToken} from "../src/LAToken.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LATokenTest is Test {
    LAToken public implementation;
    LAToken public token;
    address public admin;
    address public minter;
    address public user1;
    address public user2;
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

        // Deploy implementation
        implementation = new LAToken(address(0));

        // Deploy proxy and initialize
        bytes memory initData =
            abi.encodeWithSelector(LAToken.initialize.selector, admin, minter);
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

    function test_Initialize_RevertsWhen_CalledAgain() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        token.initialize(admin, minter);
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        implementation.initialize(admin, minter);
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
}

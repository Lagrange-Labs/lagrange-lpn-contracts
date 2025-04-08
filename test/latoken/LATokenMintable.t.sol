// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.t.sol"; // TODO
import {LATokenMintable} from "../../src/latoken/LATokenMintable.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

contract LATokenMintableTest is BaseTest {
    LATokenMintable public implementation;
    LATokenMintable public token;
    address public admin;
    address public treasury;
    address public initialMintHandler;
    address public user1;
    address public user2;
    address public user3;
    address public lzEndpoint;

    uint256 public constant INFLATION_RATE = 400; // 4%
    uint256 public constant INITIAL_SUPPLY = 1000 ether;
    uint256 public constant USER_INITIAL_BALANCE = 10 ether;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // For ERC20Permit testing
    uint256 privateKey = 0xBEEF;
    address permitUser = vm.addr(privateKey);

    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        initialMintHandler = makeAddr("initialMintHandler");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        lzEndpoint = makeMock("lzEndpoint");

        // Mock setDelegate call to LZ endpoint contract, happens in LATokenMintable.initialize
        vm.mockCall(
            lzEndpoint,
            abi.encodeWithSelector(
                ILayerZeroEndpointV2.setDelegate.selector, admin
            ),
            ""
        );

        // Deploy implementation
        implementation =
            new LATokenMintable(lzEndpoint, INFLATION_RATE, INITIAL_SUPPLY);

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            LATokenMintable.initialize.selector,
            admin,
            treasury,
            initialMintHandler
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation), admin, initData
        );

        // Get token instance pointing to the proxy
        token = LATokenMintable(address(proxy));

        // Transfer some initial tokens to user1
        vm.prank(initialMintHandler);
        token.transfer(user1, USER_INITIAL_BALANCE);

        // Fast forward time to allow minting
        vm.warp(block.timestamp + 1 days);
    }

    // ------------------------------------------------------------
    //                    INITIALIZATION TESTS                    |
    // ------------------------------------------------------------

    function test_Initialize_Success() public view {
        assertEq(token.name(), "Lagrange");
        assertEq(token.symbol(), "LA");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.ANNUAL_INFLATION_RATE_PPTT(), INFLATION_RATE);
        assertEq(token.INITIAL_SUPPLY(), INITIAL_SUPPLY);
        assertEq(
            token.balanceOf(initialMintHandler),
            INITIAL_SUPPLY - USER_INITIAL_BALANCE
        );
        assertEq(token.balanceOf(treasury), 0);
    }

    function test_Initialize_RevertsWhen_CalledAgain() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        token.initialize(admin, treasury, initialMintHandler);
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        implementation.initialize(admin, treasury, initialMintHandler);
    }

    // ------------------------------------------------------------
    //                      BASIC ERC20 TESTS                     |
    // ------------------------------------------------------------

    function test_Transfer_Success() public {
        uint256 transferAmount = 1 ether;

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user1), USER_INITIAL_BALANCE - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function test_ApproveAndTransferFrom_Success() public {
        uint256 approveAmount = 5 ether;

        vm.prank(user1);
        token.approve(user2, approveAmount);
        assertEq(token.allowance(user1, user2), approveAmount);

        uint256 transferAmount = 1 ether;
        vm.prank(user2);
        token.transferFrom(user1, user2, transferAmount);

        assertEq(token.balanceOf(user1), USER_INITIAL_BALANCE - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(user1, user2), approveAmount - transferAmount);
    }

    // ------------------------------------------------------------
    //                        MINTING TESTS                       |
    // ------------------------------------------------------------

    function test_Mint_Success() public {
        assertEq(token.balanceOf(user2), 0);
        uint256 mintAmount = token.availableToMint();
        assertTrue(mintAmount > 0);

        vm.prank(treasury);
        vm.expectEmit();
        emit LATokenMintable.Mint(user2, mintAmount);
        token.mint(user2, mintAmount);

        assertEq(token.balanceOf(user2), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
        assertEq(token.availableToMint(), 0);
    }

    function test_Mint_RevertsWhen_CallerLacksMinterRole() public {
        uint256 mintAmount = 1;

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

    function test_Mint_RevertsWhen_ExceedsAllowedInflation() public {
        // Calculate the available amount to mint based on 1 day elapsed time
        uint256 availableAmount = token.availableToMint();

        // Try to mint more than available
        uint256 excessAmount = availableAmount + 1;

        vm.prank(treasury);
        vm.expectRevert(LATokenMintable.ExceedsAllowedInflation.selector);
        token.mint(user2, excessAmount);
    }

    function test_AvailableToMint_IncreaseOverTime_Success() public {
        // 1 day after deployment (first warp happens in setup function)
        uint256 expectedAmount =
            (INITIAL_SUPPLY * 4 * 1 days) / (365 days * 100);
        uint256 actualAmount = token.availableToMint();
        assertEq(actualAmount, expectedAmount);
        // 1 year after deployment
        vm.warp(block.timestamp + 364 days); // plus the 1 day from setup = 365 days
        expectedAmount = (INITIAL_SUPPLY * 4) / 100;
        actualAmount = token.availableToMint();
        assertEq(actualAmount, expectedAmount);
        // 5 years after deployment
        vm.warp(block.timestamp + (365 days * 4)); // add 4 more years, so 5 total
        expectedAmount = (INITIAL_SUPPLY * 4 * 5) / 100;
        actualAmount = token.availableToMint();
        assertEq(actualAmount, expectedAmount);
    }

    function test_AvailableToMint_DecreaseAfterMinting_Success() public {
        // Get initial available amount
        uint256 initialAvailable = token.availableToMint();
        assertTrue(initialAvailable > 2); // need to be able to split in half for this test

        // Mint half of the available amount
        uint256 mintAmount = initialAvailable / 2;
        vm.prank(treasury);
        token.mint(user2, mintAmount);

        // Check that available amount decreased by the minted amount
        uint256 newAvailable = token.availableToMint();
        assertEq(newAvailable, initialAvailable - mintAmount);
    }

    function test_AvailableToMint_IncreasesOverTime_Success() public {
        // Get initial available amount
        uint256 initialAvailable = token.availableToMint();

        // Warp forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Check that available amount increased
        uint256 newAvailable = token.availableToMint();
        assertTrue(newAvailable > initialAvailable);

        // Calculate expected increase (30 days of inflation)
        uint256 expectedIncrease =
            (INITIAL_SUPPLY * 4 * 30 days) / (365 days * 100);
        assertApproxEqAbs(newAvailable - initialAvailable, expectedIncrease, 10);
    }

    function test_AvailableToMint_AfterMultipleMints_Success() public {
        // Mint multiple times and verify the available amount decreases correctly
        uint256 initialAvailable = token.availableToMint();

        // First mint
        uint256 firstMintAmount = initialAvailable / 4;
        vm.prank(treasury);
        token.mint(user2, firstMintAmount);

        // Check available decreased correctly
        uint256 availableAfterFirstMint = token.availableToMint();
        assertEq(availableAfterFirstMint, initialAvailable - firstMintAmount);

        // Second mint
        uint256 secondMintAmount = availableAfterFirstMint / 3;
        vm.prank(treasury);
        token.mint(user3, secondMintAmount);

        // Check available decreased correctly
        uint256 availableAfterSecondMint = token.availableToMint();
        assertEq(
            availableAfterSecondMint, availableAfterFirstMint - secondMintAmount
        );

        // Wait some time and mint again
        vm.warp(block.timestamp + 60 days);
        uint256 availableAfterTimeIncrease = token.availableToMint();

        uint256 thirdMintAmount = availableAfterTimeIncrease / 2;
        vm.prank(treasury);
        token.mint(user1, thirdMintAmount);

        // Check available decreased correctly
        uint256 availableAfterThirdMint = token.availableToMint();
        assertEq(
            availableAfterThirdMint,
            availableAfterTimeIncrease - thirdMintAmount
        );
    }

    // ------------------------------------------------------------
    //                        PERMIT TESTS                        |
    // ------------------------------------------------------------

    function test_Permit_Success() public {
        uint256 permitAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Transfer some tokens to the permitUser
        vm.prank(initialMintHandler);
        token.transfer(permitUser, USER_INITIAL_BALANCE);

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
            token.balanceOf(permitUser), USER_INITIAL_BALANCE - permitAmount
        );

        assertEq(token.balanceOf(user1), USER_INITIAL_BALANCE + permitAmount);
    }

    // ------------------------------------------------------------
    //                    ACCESS CONTROL TESTS                    |
    // ------------------------------------------------------------

    function test_GrantRole_Success() public {
        // Verify roles
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(MINTER_ROLE, treasury));

        // Grant minter role to user1
        vm.prank(admin);
        token.grantRole(MINTER_ROLE, user1);

        // Verify user1 can now mint
        vm.prank(user1);
        token.mint(user2, 1);

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

    function test_GrantRole_RevertsWhen_CalledByMemberButNotAdmin() public {
        // Verify initial roles
        assertTrue(token.hasRole(MINTER_ROLE, treasury));

        // Try to grant MINTER_ROLE from treasury (who has MINTER_ROLE but not admin)
        // to user1, which should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                treasury,
                token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(treasury);
        token.grantRole(MINTER_ROLE, user1);

        // Verify user1 did not receive the role
        assertFalse(token.hasRole(MINTER_ROLE, user1));
    }

    // ------------------------------------------------------------
    //                         OTHER TESTS                        |
    // ------------------------------------------------------------

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

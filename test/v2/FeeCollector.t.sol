// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeeCollector} from "../../src/v2/FeeCollector.sol";
import {TestERC20} from "../../src/mocks/TestERC20.sol";
import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";

contract FeeCollectorTest is Test {
    FeeCollector public feeCollector;
    TestERC20 public token;

    address public owner;
    address public stranger;
    address public recipient;
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant TRANSFER_AMOUNT = 1 ether;

    function setUp() public {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");
        recipient = makeAddr("recipient");

        vm.deal(stranger, INITIAL_BALANCE);

        feeCollector = new FeeCollector(owner);

        token = new TestERC20();
        token.mint(stranger, INITIAL_BALANCE);
    }

    function test_Constructor() public view {
        assertEq(feeCollector.owner(), owner);
        assertEq(feeCollector.version(), "1.0.0");
    }

    function test_ReceiveNative_Success() public {
        vm.prank(stranger);
        vm.expectEmit();
        emit FeeCollector.NativeReceived(stranger, TRANSFER_AMOUNT);

        (bool success,) = address(feeCollector).call{value: TRANSFER_AMOUNT}("");
        assertTrue(success);
        assertEq(address(feeCollector).balance, TRANSFER_AMOUNT);
    }

    function test_ReceiveERC20_Success() public {
        vm.startPrank(stranger);
        token.approve(address(feeCollector), TRANSFER_AMOUNT);

        vm.expectEmit();
        emit FeeCollector.ERC20Received(
            address(token), stranger, TRANSFER_AMOUNT
        );

        feeCollector.receiveERC20(address(token), TRANSFER_AMOUNT);
        vm.stopPrank();

        assertEq(token.balanceOf(address(feeCollector)), TRANSFER_AMOUNT);
        assertEq(token.balanceOf(stranger), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    function test_WithdrawNative_Success() public {
        vm.deal(address(feeCollector), TRANSFER_AMOUNT);

        uint256 initialBalance = recipient.balance;

        vm.prank(owner);
        vm.expectEmit();
        emit FeeCollector.NativeWithdrawn(recipient, TRANSFER_AMOUNT);

        feeCollector.withdrawNative(recipient);

        assertEq(address(feeCollector).balance, 0);
        assertEq(recipient.balance, initialBalance + TRANSFER_AMOUNT);
    }

    function test_WithdrawNative_RevertIf_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, stranger
            )
        );
        feeCollector.withdrawNative(stranger);
    }

    function test_WithdrawERC20_Success() public {
        token.mint(address(feeCollector), TRANSFER_AMOUNT);

        vm.prank(owner);
        vm.expectEmit();
        emit FeeCollector.ERC20Withdrawn(
            address(token), recipient, TRANSFER_AMOUNT
        );

        feeCollector.withdrawERC20(address(token), recipient);

        assertEq(token.balanceOf(address(feeCollector)), 0);
        assertEq(token.balanceOf(recipient), TRANSFER_AMOUNT);
    }

    function test_WithdrawERC20_RevertIf_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, stranger
            )
        );
        feeCollector.withdrawERC20(address(token), stranger);
    }
}

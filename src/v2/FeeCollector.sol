// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FeeCollector
/// @notice Collects fees from on-chain components within the Lagrange ecosystem
contract FeeCollector is IVersioned, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice The semantic version of the contract
    string public constant VERSION = "1.0.0";

    /// @notice Emitted when native tokens are received
    event NativeReceived(address indexed sender, uint256 amount);

    /// @notice Emitted when ERC20 tokens are received
    event ERC20Received(
        address indexed token, address indexed sender, uint256 amount
    );

    /// @notice Emitted when native tokens are withdrawn
    event NativeWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when ERC20 tokens are withdrawn
    event ERC20Withdrawn(
        address indexed token, address indexed to, uint256 amount
    );

    /// @notice Error thrown when a token transfer fails
    error TransferFailed();

    /// @notice Error thrown when a token transfer is attempted to the zero address
    error CannotTransferToZeroAddress();

    /// @notice Constructor to set initial owner
    /// @param initialOwner The address of the initial owner
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Allows the contract to receive native tokens
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    /// @notice Receives ERC20 tokens from a sender
    /// @param token The ERC20 token contract address
    /// @param amount The amount of tokens to transfer
    /// @dev Rather than trust the value of "amount" passed as a param, we calculate the actual
    /// amount received by checking the balance before and after the transfer. This is useful
    /// for some tokens that implement fee-on-transfer mechanisms or have special transfer rules
    /// for uint256.max
    function receiveERC20(address token, uint256 amount) external {
        uint256 received = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        received = IERC20(token).balanceOf(address(this)) - received;
        emit ERC20Received(token, msg.sender, received);
    }

    /// @notice Withdraws all native tokens to a specified address
    /// @param to The address to withdraw tokens to
    /// @dev Only callable by owner
    function withdrawNative(address to) external onlyOwner {
        if (to == address(0)) {
            revert CannotTransferToZeroAddress();
        }
        uint256 balance = address(this).balance;
        (bool success,) = to.call{value: balance}("");
        if (!success) {
            revert TransferFailed();
        }
        emit NativeWithdrawn(to, balance);
    }

    /// @notice Withdraws ERC20 tokens to a specified address
    /// @param token The ERC20 token contract address
    /// @param to The address to withdraw tokens to
    /// @dev Only callable by owner
    function withdrawERC20(address token, address to) external onlyOwner {
        if (to == address(0)) {
            revert CannotTransferToZeroAddress();
        }
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, balance);
        emit ERC20Withdrawn(token, to, balance);
    }
}

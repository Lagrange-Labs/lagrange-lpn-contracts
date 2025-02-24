// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";

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

    /// @notice Constructor to set initial owner
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Allows the contract to receive native tokens
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    /// @notice Receives ERC20 tokens from a sender
    /// @param token The ERC20 token contract address
    /// @param amount The amount of tokens to transfer
    function receiveERC20(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit ERC20Received(token, msg.sender, amount);
    }

    /// @notice Withdraws all native tokens to a specified address
    /// @param to The address to withdraw tokens to
    /// @dev Only callable by owner
    function withdrawNative(address to) external onlyOwner {
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
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, balance);
        emit ERC20Withdrawn(token, to, balance);
    }
}

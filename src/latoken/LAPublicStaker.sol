// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVersioned} from "../interfaces/IVersioned.sol";

/// @title LAPublicStaker
/// @author Lagrange Engineering
/// @notice This contract is used to stake LA tokens and claim rewards
/// @dev This contract is optimized for flexibility of configuration, by allowing
/// the owner to change the APY, lockup period, and stake cap at any point.
/// @dev This contract allows with $LA to stake
contract LAPublicStaker is
    Initializable,
    Ownable2StepUpgradeable,
    IVersioned
{
    struct Config {
        uint16 apyPPT; // APY in parts per thousand (1% = 10)
        uint16 lockupPeriodDays; // Lockup period in days
        uint96 stakeCap; // Maximum amount of LA tokens that can be staked
    }

    struct State {
        uint16 apyPPT; // See Config
        uint16 lockupPeriodDays; // See Config
        uint96 stakeCap; // See Config
        uint96 totalStaked; // Total amount of LA tokens that have been staked so far
    }

    struct StakePosition {
        uint96 amountStaked; // Amount of LA tokens staked by the user
        uint96 rewardsOwed; // Amount of LA tokens owed to the user as interest
        uint48 matureDate; // Date when the user can claim their rewards
    }

    struct PositionQueue {
        StakePosition[] positions; // Array of a user's positions, ordered in the order they were staked
        uint256 offset; // Offset of the first position in the array that is active
    }

    event Claimed(address indexed user, uint256 amount);
    event ConfigSet(Config config);
    event Distributed(address indexed to, uint256 amount);
    event Staked(address indexed user, uint256 amount);

    error InvalidAmount();
    error InvalidConfig();
    error InvalidRecipient();
    error NoClaimableStake();
    error OnlyTreasuryCanDistribute();
    error StakeCapExceeded();
    error TransferFailed();
    error ZeroAddress();

    string public constant VERSION = "1.0.0";

    IERC20 public immutable LA_TOKEN;
    address public immutable TREASURY;

    State private s_state;

    // stake entries are ordered by stake date
    mapping(address => PositionQueue) private s_userStakes;

    /// @notice Creates a new LAPublicStaker contract
    /// @param laToken The address of the LA token contract
    /// @param treasury The address of the treasury contract
    constructor(address laToken, address treasury) {
        if (laToken == address(0)) revert ZeroAddress();
        if (treasury == address(0)) revert ZeroAddress();

        LA_TOKEN = IERC20(laToken);
        TREASURY = treasury;

        _disableInitializers();
    }

    /// @notice Initializes the contract with an owner and configuration
    /// @param initialOwner The address of the initial owner
    /// @param config The initial configuration for the contract
    function initialize(address initialOwner, Config calldata config)
        public
        initializer
    {
        __Ownable_init(initialOwner);
        _setConfig(config);
    }

    /// @notice Sets a new configuration for the staking contract
    /// @param config The new configuration to set
    function setConfig(Config calldata config) external onlyOwner {
        _setConfig(config);
    }

    /// @notice Stakes LA tokens for the caller
    /// @param amount The amount of LA tokens to stake
    function stake(uint256 amount) external {
        State memory state = s_state;

        if (amount == 0) revert InvalidAmount();
        if (amount + state.totalStaked > state.stakeCap) {
            revert StakeCapExceeded();
        }

        s_state.totalStaked = state.totalStaked + uint96(amount);

        uint256 rewardsOwed =
            (amount * state.apyPPT * state.lockupPeriodDays) / 365000;

        // Handle edge case where too little $LA is staked to earn any rewards
        if (rewardsOwed == 0) {
            revert InvalidAmount();
        }

        s_userStakes[msg.sender].positions.push(
            StakePosition({
                amountStaked: uint96(amount),
                rewardsOwed: uint96(rewardsOwed),
                matureDate: uint48(
                    block.timestamp + (uint256(state.lockupPeriodDays) * 1 days)
                )
            })
        );

        // Transfer LA tokens from user
        if (!LA_TOKEN.transferFrom(msg.sender, address(this), uint256(amount)))
        {
            revert TransferFailed();
        }

        emit Staked(msg.sender, amount);
    }

    /// @notice Claims all available stakes and interest for the caller
    /// @dev This function could be expensive for large arrays of positions,
    /// but we don't expect this to be the case, so we don't optimize for it
    /// @dev It is possible that a stake positon might mature before other stake positions
    /// with smaller inicies, so we may delete positions from the middle of the array.
    /// For this reason, it is important to always check that positions are still valid
    /// before considering them.
    // slither-disable-next-line arbitrary-send-erc20
    function claim() external {
        uint256 length = s_userStakes[msg.sender].positions.length;
        uint256 offset = s_userStakes[msg.sender].offset;

        uint256 totalClaimable;
        bool shouldShift = true;
        StakePosition memory position;

        for (uint256 i = offset; i < length; ++i) {
            position = s_userStakes[msg.sender].positions[i];

            if (position.matureDate <= block.timestamp) {
                totalClaimable += position.amountStaked + position.rewardsOwed;
                if (shouldShift) ++offset;
                delete s_userStakes[msg.sender].positions[i];
            } else {
                shouldShift = false; // Stop shifting if we've found an immature position
            }
        }

        if (totalClaimable == 0) revert NoClaimableStake();

        s_userStakes[msg.sender].offset = offset;

        // If the contract's $LA balance is too low, transfer from treasury first
        uint256 contractBalance = LA_TOKEN.balanceOf(address(this));
        if (contractBalance < totalClaimable) {
            if (
                !LA_TOKEN.transferFrom(
                    TREASURY, address(this), totalClaimable - contractBalance
                )
            ) revert TransferFailed();
        }

        // Transfer $LA tokens to the user
        if (!LA_TOKEN.transfer(msg.sender, totalClaimable)) {
            revert TransferFailed();
        }

        emit Claimed(msg.sender, totalClaimable);
    }

    /// @notice Distributes LA tokens to a recipient
    /// @param to The address of the recipient
    /// @param amount The amount of LA tokens to distribute
    function distribute(address to, uint256 amount) external {
        if (msg.sender != TREASURY) revert OnlyTreasuryCanDistribute();
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        if (!LA_TOKEN.transfer(to, amount)) revert TransferFailed();

        emit Distributed(to, amount);
    }

    /// @notice Gets the current configuration
    /// @return Config The current configuration
    function getConfig() public view returns (Config memory) {
        return Config({
            apyPPT: s_state.apyPPT,
            lockupPeriodDays: s_state.lockupPeriodDays,
            stakeCap: s_state.stakeCap
        });
    }

    /// @notice Gets the total amount of LA tokens that have been staked
    /// @return uint256 The total amount of LA tokens that have been staked
    function getTotalStaked() public view returns (uint256) {
        return s_state.totalStaked;
    }

    /// @notice Gets the stakes for a user
    /// @param user The address of the user to check
    /// @return StakePosition[] The stakes for the user
    function getStakePositions(address user)
        public
        view
        returns (StakePosition[] memory)
    {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        StakePosition[] memory positions = new StakePosition[](length - offset);

        uint256 count;
        for (uint256 i = offset; i < length; ++i) {
            if (s_userStakes[user].positions[i].amountStaked > 0) {
                positions[count] = s_userStakes[user].positions[i];
                ++count;
            }
        }

        assembly {
            mstore(positions, count)
        }

        return positions;
    }

    /// @notice Checks if a user has any stakes available to claim
    /// @param user The address of the user to check
    /// @return bool True if the user has stakes available to claim
    function hasClaimableRewards(address user) public view returns (bool) {
        uint256 length = s_userStakes[user].positions.length;

        for (uint256 i = s_userStakes[user].offset; i < length; ++i) {
            if (
                s_userStakes[user].positions[i].amountStaked > 0
                    && s_userStakes[user].positions[i].matureDate <= block.timestamp
            ) {
                return true;
            }
        }

        return false;
    }

    /// @notice Gets the total amount of LA tokens that a user can claim
    /// @param user The address of the user to check
    /// @return uint256 The total amount of LA tokens that can be claimed
    function getCurrentClaimableAmount(address user)
        public
        view
        returns (uint256)
    {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 total;
        for (uint256 i = offset; i < length; ++i) {
            if (s_userStakes[user].positions[i].matureDate <= block.timestamp) {
                total += s_userStakes[user].positions[i].amountStaked
                    + s_userStakes[user].positions[i].rewardsOwed;
            }
        }

        return total;
    }

    /// @notice Gets the next payout date for a user's stakes
    /// @param user The address of the user to check
    /// @return uint256 The timestamp of the next payout date
    /// @dev Returns 0 if there is nothing at stake, and thus no payout date
    /// @dev Returns 0 if all stakes are mature
    function getNextRewardDate(address user) public view returns (uint256) {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 nextPayoutDate;
        for (uint256 i = offset; i < length; ++i) {
            uint256 payoutDate = s_userStakes[user].positions[i].matureDate;
            if (
                payoutDate > block.timestamp
                    && (payoutDate < nextPayoutDate || nextPayoutDate == 0)
            ) {
                nextPayoutDate = payoutDate;
            }
        }

        return nextPayoutDate;
    }

    /// @notice Gets the amount of LA tokens that will be paid out on the next payout date
    /// @param user The address of the user to check
    /// @return uint256 The amount of LA tokens that will be paid out
    /// @dev Returns 0 if there is nothing at stake, and thus no payout amount
    /// @dev Will return 0 if all stakes are mature
    /// @dev Thus function is inefficient, but we don't expect it to be called in txs
    function getNextRewardAmount(address user) public view returns (uint256) {
        uint256 nextPayoutDate = getNextRewardDate(user);
        if (nextPayoutDate == 0) {
            return 0;
        }

        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 total; // unlikely, but it is possible to have multiple positions with the same payout date

        for (uint256 i = offset; i < length; ++i) {
            if (s_userStakes[user].positions[i].matureDate == nextPayoutDate) {
                total += s_userStakes[user].positions[i].amountStaked
                    + s_userStakes[user].positions[i].rewardsOwed;
            }
        }

        return total;
    }

    /// @notice Gets the total amount of LA tokens staked by a user
    /// @param user The address of the user to check
    /// @return uint256 The total amount of LA tokens staked
    function getTotalStaked(address user) public view returns (uint256) {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 total;
        for (uint256 i = offset; i < length; ++i) {
            total += s_userStakes[user].positions[i].amountStaked;
        }

        return total;
    }

    /// @notice Gets the total amount of interest owed to a user
    /// @param user The address of the user to check
    /// @return uint256 The total amount of interest owed
    function getTotalPendingRewards(address user)
        public
        view
        returns (uint256)
    {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 total;
        for (uint256 i = offset; i < length; ++i) {
            total += s_userStakes[user].positions[i].rewardsOwed;
        }
        return total;
    }

    /// @notice Gets the total amount of pending payouts for a user
    /// @param user The address of the user to check
    /// @return uint256 The total amount of pending payouts
    function getTotalPendingPayout(address user)
        public
        view
        returns (uint256)
    {
        uint256 offset = s_userStakes[user].offset;
        uint256 length = s_userStakes[user].positions.length;

        uint256 total;
        for (uint256 i = offset; i < length; ++i) {
            total += s_userStakes[user].positions[i].rewardsOwed
                + s_userStakes[user].positions[i].amountStaked;
        }
        return total;
    }

    /// @notice Internal function to validate and set configuration
    /// @param config The configuration to validate and set
    function _setConfig(Config calldata config) private {
        if (config.apyPPT == 0) revert InvalidConfig();
        if (config.lockupPeriodDays == 0) revert InvalidConfig();
        if (config.stakeCap == 0) revert InvalidConfig();

        s_state.apyPPT = config.apyPPT;
        s_state.lockupPeriodDays = config.lockupPeriodDays;
        s_state.stakeCap = config.stakeCap;

        emit ConfigSet(config);
    }
}

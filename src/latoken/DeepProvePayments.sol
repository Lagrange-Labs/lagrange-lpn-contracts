// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVersioned} from "../interfaces/IVersioned.sol";

/// @title DeepProvePayments
/// @author Lagrange Engineering
/// @notice This contract is used to establish an escrow agreement between a client and Lagrange
/// This contract is not open to the public. These escrow agreements are pre-established with the client.
contract DeepProvePayments is
    Initializable,
    Ownable2StepUpgradeable,
    IVersioned
{
    struct NewEscrowAgreementParams {
        uint88 paymentAmount; // Amount of LA tokens staked by the user, max of 2^88 - 1 is approx 300M LA
        uint88 rebateAmount; // Amount of LA tokens the user is eligible to claim as rebate, per claim
        uint16 durationDays; // Number of days that the user can claim regular rebates during
        uint16 numRebates; // Number of rebates the user is eligible to claim over the rebate period
    }

    struct EscrowAgreement {
        uint88 paymentAmount; // See NewAgreementParams
        uint88 rebateAmount; // See NewAgreementParams
        uint16 durationDays; // See NewAgreementParams
        uint16 numRebates; // See NewAgreementParams
        uint16 numRebatesClaimed; // Number of rebates claimed for this agreement
        uint32 activationDate; // Date when the user deposits their LA tokens
    }

    event Distributed(address indexed to, uint256 amount);
    event AgreementActivated(address indexed user);
    event NewAgreement(address indexed user, EscrowAgreement agreement);
    event RebateClaimed(address indexed user, uint256 amount);

    error AgreementAlreadyActivated();
    error AgreementAlreadyExists();
    error InvalidAgreement();
    error InvalidAmount();
    error InvalidConfig();
    error NoClaimableRebates();
    error OnlyTreasuryCanDistribute();
    error TransferFailed();
    error ZeroAddress();

    string public constant VERSION = "1.0.0";

    IERC20 public immutable LA_TOKEN;
    address public immutable TREASURY; // TODO: rename "Guarantor"
    address public immutable FEE_COLLECTOR;

    mapping(address => EscrowAgreement) public s_agreements;

    /// @notice Creates a new DeepProvePayments contract
    /// @param laToken The address of the LA token contract
    /// @param treasury The address of the treasury contract
    /// @param feeCollector The address of the fee collector contract
    constructor(address laToken, address treasury, address feeCollector) {
        if (laToken == address(0)) revert ZeroAddress();
        if (treasury == address(0)) revert ZeroAddress();
        if (feeCollector == address(0)) revert ZeroAddress();

        LA_TOKEN = IERC20(laToken);
        TREASURY = treasury;
        FEE_COLLECTOR = feeCollector;

        _disableInitializers();
    }

    /// @notice Initializes the contract with an owner and configuration
    /// @param initialOwner The address of the initial owner
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    /// @notice Creates a new EscrowAgreement for a given address (owner only)
    /// @param user The address to create the agreement for
    /// @param params The params for the new agreement
    function createAgreement(
        address user,
        NewEscrowAgreementParams calldata params
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (params.paymentAmount == 0) revert InvalidAmount();
        if (params.rebateAmount == 0) revert InvalidAmount();
        if (params.durationDays == 0) revert InvalidConfig();
        if (params.numRebates == 0) revert InvalidConfig();

        if (s_agreements[user].activationDate != 0) {
            revert AgreementAlreadyExists();
        }

        EscrowAgreement memory agreement = EscrowAgreement({
            paymentAmount: params.paymentAmount,
            rebateAmount: params.rebateAmount,
            durationDays: params.durationDays,
            numRebates: params.numRebates,
            numRebatesClaimed: 0,
            activationDate: 0
        });

        s_agreements[user] = agreement;

        emit NewAgreement(user, agreement);
    }

    /// @notice Activates the escrow agreement for the caller by transferring LA tokens to the contract
    /// @dev This function can only be called once per agreement. The caller must have approved the contract to spend their LA tokens.
    /// @dev Reverts if no agreement exists for the caller or if the agreement has already been activated.
    function activateAgreement() external {
        EscrowAgreement memory agreement = s_agreements[msg.sender];
        if (agreement.paymentAmount == 0) {
            revert InvalidAgreement();
        }

        if (agreement.activationDate != 0) {
            revert AgreementAlreadyActivated();
        }

        s_agreements[msg.sender].activationDate = uint32(block.timestamp);

        // Transfer LA tokens from user
        if (
            !LA_TOKEN.transferFrom(
                msg.sender, address(this), uint256(agreement.paymentAmount)
            )
        ) {
            revert TransferFailed();
        }

        emit AgreementActivated(msg.sender);
    }

    /// @notice Claims all available rebates for the caller
    // slither-disable-next-line arbitrary-send-erc20
    function claimRebates() external {
        EscrowAgreement memory agreement = s_agreements[msg.sender];
        if (agreement.activationDate == 0) revert InvalidAgreement();

        (bool isLastClaim, uint256 totalClaimable, uint16 numClaimableRebates) =
            _processClaim(agreement);

        if (numClaimableRebates == 0) revert NoClaimableRebates();

        if (isLastClaim) {
            delete s_agreements[msg.sender];
        } else {
            s_agreements[msg.sender].numRebatesClaimed =
                agreement.numRebatesClaimed + numClaimableRebates;
        }

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

        emit RebateClaimed(msg.sender, totalClaimable);
    }

    /// @notice Distributes LA tokens to the fee collector
    /// @param amount The amount of LA tokens to distribute
    function distribute(uint256 amount) external {
        if (msg.sender != TREASURY) revert OnlyTreasuryCanDistribute();
        if (amount == 0) revert InvalidAmount();

        if (!LA_TOKEN.transfer(FEE_COLLECTOR, amount)) revert TransferFailed();

        emit Distributed(FEE_COLLECTOR, amount);
    }

    /// @notice Cancels an escrow agreement for a given address
    /// @param user The address of the user to cancel the agreement for
    /// @dev This cancels the user's future rebate claims
    function cancelAgreement(address user) external onlyOwner {
        EscrowAgreement memory agreement = s_agreements[user];
        if (agreement.paymentAmount == 0) revert InvalidAgreement();
        delete s_agreements[user];
    }

    /// @notice Gets the stakes for a user
    /// @param user The address of the user to check
    /// @return EscrowAgreement The agreement for the user
    function getEscrowAgreement(address user)
        public
        view
        returns (EscrowAgreement memory)
    {
        return s_agreements[user];
    }

    /// @notice Checks if a user has any stakes available to claim
    /// @param user The address of the user to check
    /// @return bool True if the user has stakes available to claim
    /// @dev External view function, not for use in txs
    function hasClaimableRebates(address user) external view returns (bool) {
        return getCurrentClaimableAmount(user) > 0;
    }

    /// @notice Gets the total amount of LA tokens that a user can claim
    /// @param user The address of the user to check
    /// @return uint256 The total amount of LA tokens that can be claimed
    /// @dev External view function, not for use in txs
    function getCurrentClaimableAmount(address user)
        public
        view
        returns (uint256)
    {
        EscrowAgreement memory agreement = s_agreements[user];
        if (agreement.activationDate == 0) return 0;

        (, uint256 totalClaimable,) = _processClaim(agreement);

        return totalClaimable;
    }

    /// @notice Gets the next payout date for a user's stakes
    /// @param user The address of the user to check
    /// @return uint256 The timestamp of the next payout date
    /// @dev Returns 0 if there is nothing at stake, and thus no payout date
    /// @dev External view function, not for use in txs
    function getNextRebateClaimDate(address user)
        public
        view
        returns (uint256)
    {
        EscrowAgreement memory agreement = s_agreements[user];

        uint256 agreementDuration = uint256(agreement.durationDays) * 1 days;

        if (agreement.activationDate == 0) return 0;
        if (block.timestamp >= agreement.activationDate + agreementDuration) {
            return 0;
        }

        uint256 numDistributionsPassed = (
            block.timestamp - agreement.activationDate
        ) * uint256(agreement.numRebates) / agreementDuration;

        return agreement.activationDate
            + (
                (numDistributionsPassed + 1)
                    * (agreementDuration / agreement.numRebates)
            );
    }

    /// @notice Processes a claim calculation for an escrow agreement
    /// @param agreement The escrow agreement to process
    /// @return isLastClaim True if this is the final claim for the agreement
    /// @return totalClaimable The total amount of LA tokens that can be claimed
    /// @return numClaimableRebates The number of rebates that can be claimed
    /// @dev This function calculates the claimable amount based on the time elapsed since activation
    /// @dev and the number of rebates already claimed. It handles both regular claims and final claims.
    function _processClaim(EscrowAgreement memory agreement)
        private
        view
        returns (bool, uint256, uint16)
    {
        bool isLastClaim = agreement.activationDate
            + uint256(agreement.durationDays) * 1 days <= block.timestamp;

        uint256 numClaimableRebates = isLastClaim
            ? agreement.numRebates - agreement.numRebatesClaimed
            : (
                (
                    (block.timestamp - agreement.activationDate)
                        * uint256(agreement.numRebates)
                ) / (uint256(agreement.durationDays) * 1 days)
            ) - agreement.numRebatesClaimed;

        uint256 totalClaimable = numClaimableRebates * agreement.rebateAmount;

        return (isLastClaim, totalClaimable, uint16(numClaimableRebates));
    }
}

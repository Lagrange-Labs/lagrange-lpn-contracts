// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

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
    using SafeCast for uint256;

    struct User {
        bool isWhitelisted; // Whether the user is approved to use DeepProve or not
        uint88 aLaCarteBalance; // Amount of LA tokens the user can use for a la carte charges
        EscrowAgreement escrowAgreement; // The escrow agreement for the user (if any)
    }

    struct EscrowAgreement {
        uint56 depositAmountGwei; // Amount of LA tokens deposited by the user (max value is 72M LA)
        uint48 rebateAmountGwei; // Amount of LA tokens the user is eligible to claim as rebate, per claim (max value is 281K LA)
        uint88 balance; // Current balance available for charges (max value is 300M LA)
        uint16 durationDays; // Number of days that the user can claim regular rebates during
        uint8 numRebates; // Number of rebates the user is eligible to claim over the rebate period
        uint8 numRebatesClaimed; // Number of rebates claimed for this agreement
        uint32 activationDate; // Date when the user deposits their LA tokens
    }

    event Charged(address indexed user, uint256 amount);
    event AgreementActivated(address indexed user);
    event NewAgreement(address indexed user, EscrowAgreement agreement);
    event RebateClaimed(address indexed user, uint256 amount);
    event TopUp(address indexed from, address indexed to, uint256 amount);

    error AgreementAlreadyActivated();
    error AgreementAlreadyExists();
    error InsufficientBalance();
    error InvalidAgreement();
    error InvalidAmount();
    error InvalidConfig();
    error NoClaimableRebates();
    error OnlyBillerCanCharge();
    error TransferFailed();
    error UserNotWhitelisted();
    error ZeroAddress();

    string public constant VERSION = "1.0.0";

    IERC20 public immutable LA_TOKEN;
    address public immutable GUARANTOR;
    address public immutable FEE_COLLECTOR;

    mapping(address => User) private s_users;
    address private s_biller;

    /// @notice Creates a new DeepProvePayments contract
    /// @param laToken The address of the LA token contract
    /// @param guarantor The address of the entity that guarantees the availability of LA tokens for rebate payments
    /// @param feeCollector The address of the fee collector contract
    constructor(address laToken, address guarantor, address feeCollector) {
        if (laToken == address(0)) revert ZeroAddress();
        if (guarantor == address(0)) revert ZeroAddress();
        if (feeCollector == address(0)) revert ZeroAddress();

        LA_TOKEN = IERC20(laToken);
        GUARANTOR = guarantor;
        FEE_COLLECTOR = feeCollector;

        _disableInitializers();
    }

    /// @notice Initializes the contract with an owner and configuration
    /// @param initialOwner The address of the initial owner
    /// @param biller The address of the biller
    function initialize(address initialOwner, address biller)
        public
        initializer
    {
        if (biller == address(0)) revert ZeroAddress();
        __Ownable_init(initialOwner);
        s_biller = biller;
    }

    /// @notice Creates a new EscrowAgreement for a given address (owner only)
    /// @param user The address to create the agreement for
    /// @param depositAmount The amount of LA tokens to deposit
    /// @param rebateAmount The amount of LA tokens to claim as rebate
    /// @param durationDays The number of days that the user can claim regular rebates during
    /// @param numRebates The number of rebates the user is eligible to claim over the rebate period
    /// @dev The depositAmount and rebateAmounts are provided in wei, but must be divisible by 10**9 for storage as gwei
    function createAgreement(
        address user,
        uint256 depositAmount,
        uint256 rebateAmount,
        uint16 durationDays,
        uint8 numRebates
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();

        if (depositAmount == 0) revert InvalidAmount();
        if (depositAmount % 1e9 != 0) revert InvalidAmount();

        if (rebateAmount == 0) revert InvalidAmount();
        if (rebateAmount % 1e9 != 0) revert InvalidAmount();

        if (durationDays == 0) revert InvalidConfig();
        if (numRebates == 0) revert InvalidConfig();

        if (s_users[user].escrowAgreement.activationDate != 0) {
            revert AgreementAlreadyExists();
        }

        EscrowAgreement memory agreement = EscrowAgreement({
            depositAmountGwei: (depositAmount / 1e9).toUint56(),
            rebateAmountGwei: (rebateAmount / 1e9).toUint48(),
            balance: 0,
            durationDays: durationDays,
            numRebates: numRebates,
            numRebatesClaimed: 0,
            activationDate: 0
        });

        s_users[user].escrowAgreement = agreement;
        s_users[user].isWhitelisted = true; // creating a new agreement automatically whitelists the user

        emit NewAgreement(user, agreement);
    }

    /// @notice Activates the escrow agreement for the caller by transferring LA tokens to the contract
    /// @dev This function can only be called once per agreement. The caller must have approved the contract to spend their LA tokens.
    /// @dev Reverts if no agreement exists for the caller or if the agreement has already been activated.
    function activateAgreement() external {
        EscrowAgreement memory agreement = s_users[msg.sender].escrowAgreement;
        if (agreement.depositAmountGwei == 0) {
            revert InvalidAgreement();
        }

        if (agreement.activationDate != 0) {
            revert AgreementAlreadyActivated();
        }

        agreement.balance =
            (uint256(agreement.depositAmountGwei) * 1e9).toUint88();
        agreement.activationDate = uint32(block.timestamp);
        s_users[msg.sender].escrowAgreement = agreement;
        s_users[msg.sender].isWhitelisted = true;

        // Transfer LA tokens from user
        if (
            !LA_TOKEN.transferFrom(
                msg.sender,
                address(this),
                uint256(agreement.depositAmountGwei) * 1e9
            )
        ) {
            revert TransferFailed();
        }

        emit AgreementActivated(msg.sender);
    }

    /// @notice Claims all available rebates for the caller
    // slither-disable-next-line arbitrary-send-erc20
    function claimRebates() external {
        EscrowAgreement memory agreement = s_users[msg.sender].escrowAgreement;
        if (agreement.activationDate == 0) revert InvalidAgreement();

        (uint256 totalClaimable, uint8 numClaimableRebates) =
            _processClaim(agreement);

        if (numClaimableRebates == 0) revert NoClaimableRebates();

        s_users[msg.sender].escrowAgreement.numRebatesClaimed =
            agreement.numRebatesClaimed + numClaimableRebates;

        // If the contract's $LA balance is too low, transfer from guarantor first
        uint256 contractBalance = LA_TOKEN.balanceOf(address(this));
        if (contractBalance < totalClaimable) {
            if (
                !LA_TOKEN.transferFrom(
                    GUARANTOR, address(this), totalClaimable - contractBalance
                )
            ) revert TransferFailed();
        }

        // Transfer $LA tokens to the user
        if (!LA_TOKEN.transfer(msg.sender, totalClaimable)) {
            revert TransferFailed();
        }

        emit RebateClaimed(msg.sender, totalClaimable);
    }

    /// @notice Charges a user for a specific amount of LA tokens
    /// @param user The address of the user to charge
    /// @param amount The amount of LA tokens to charge
    /// @dev Charges against escrow balance first, then a la carte balance
    function charge(address user, uint88 amount) external {
        if (msg.sender != s_biller) revert OnlyBillerCanCharge();
        if (amount == 0) revert InvalidAmount();

        User memory userStruct = s_users[user];
        uint256 totalBalance = uint256(userStruct.escrowAgreement.balance)
            + uint256(userStruct.aLaCarteBalance);

        if (totalBalance < amount) revert InsufficientBalance();

        // First, charge against escrow balance
        if (userStruct.escrowAgreement.balance >= amount) {
            userStruct.escrowAgreement.balance -= amount;
        } else {
            // Charge remaining from a la carte balance
            userStruct.aLaCarteBalance = userStruct.aLaCarteBalance
                - (amount - userStruct.escrowAgreement.balance);
            userStruct.escrowAgreement.balance = 0;
        }

        s_users[user] = userStruct; // update balances

        // Transfer tokens to fee collector from contract
        if (!LA_TOKEN.transfer(FEE_COLLECTOR, amount)) {
            revert TransferFailed();
        }

        emit Charged(user, uint256(amount));
    }

    /// @notice Allows any user to top up the a la carte balance of a whitelisted user
    /// @param user The address of the whitelisted user to top up
    /// @param amount The amount of LA tokens to top up (in wei)
    /// @dev The recipient user must be whitelisted. The caller must have sufficient LA token balance and approval
    function topUp(address user, uint88 amount) external {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (!s_users[user].isWhitelisted) revert UserNotWhitelisted();

        // Transfer LA tokens from caller to contract
        if (!LA_TOKEN.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        // Increase the user's a la carte balance
        s_users[user].aLaCarteBalance += amount;

        emit TopUp(msg.sender, user, amount);
    }

    /// @notice Cancels an escrow agreement for a given address
    /// @param user The address of the user to cancel the agreement for
    /// @dev This cancels the user's future rebate claims
    function cancelAgreement(address user) external onlyOwner {
        EscrowAgreement memory agreement = s_users[user].escrowAgreement;
        if (agreement.depositAmountGwei == 0) revert InvalidAgreement();
        delete s_users[user].escrowAgreement;
    }

    /// @notice Gets the biller address
    /// @return address The current biller address
    function getBiller() external view returns (address) {
        return s_biller;
    }

    /// @notice Gets the total balance for a user (escrow + a la carte)
    /// @param user The address of the user to check
    /// @return uint256 The total balance for the user
    function getBalance(address user) external view returns (uint256) {
        User memory userStruct = s_users[user];
        return uint256(userStruct.escrowAgreement.balance)
            + uint256(userStruct.aLaCarteBalance);
    }

    /// @notice Gets the escrow balance for a user
    /// @param user The address of the user to check
    /// @return uint88 The escrow balance for the user
    function getEscrowBalance(address user) external view returns (uint88) {
        return s_users[user].escrowAgreement.balance;
    }

    /// @notice Gets the a la carte balance for a user
    /// @param user The address of the user to check
    /// @return uint88 The a la carte balance for the user
    function getALaCarteBalance(address user) external view returns (uint88) {
        return s_users[user].aLaCarteBalance;
    }

    /// @notice Gets the whitelisted status for a user
    /// @param user The address of the user to check
    /// @return bool True if the user is whitelisted
    function isWhitelisted(address user) external view returns (bool) {
        return s_users[user].isWhitelisted;
    }

    /// @notice Sets the whitelisted status for a user (owner only)
    /// @param user The address of the user to set status for
    /// @param whitelisted The new whitelisted status
    function setWhitelisted(address user, bool whitelisted)
        external
        onlyOwner
    {
        if (user == address(0)) revert ZeroAddress();
        s_users[user].isWhitelisted = whitelisted;
    }

    /// @notice Sets the biller address (owner only)
    /// @param newBiller The new biller address
    function setBiller(address newBiller) external onlyOwner {
        if (newBiller == address(0)) revert ZeroAddress();
        s_biller = newBiller;
    }

    function getEscrowAgreement(address user)
        public
        view
        returns (EscrowAgreement memory)
    {
        return s_users[user].escrowAgreement;
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
        EscrowAgreement memory agreement = s_users[user].escrowAgreement;
        if (agreement.activationDate == 0) return 0;

        (uint256 totalClaimable,) = _processClaim(agreement);

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
        EscrowAgreement memory agreement = s_users[user].escrowAgreement;

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
    /// @return totalClaimable The total amount of LA tokens that can be claimed
    /// @return numClaimableRebates The number of rebates that can be claimed
    /// @dev This function calculates the claimable amount based on the time elapsed since activation
    /// @dev and the number of rebates already claimed. It handles both regular claims and final claims.
    function _processClaim(EscrowAgreement memory agreement)
        private
        view
        returns (uint256, uint8)
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

        uint256 totalClaimable =
            numClaimableRebates * uint256(agreement.rebateAmountGwei) * 1e9;

        return (totalClaimable, uint8(numClaimableRebates));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LATokenBase} from "./LATokenBase.sol";

/// @title LATokenMintable
/// @notice This is the eth mainnet version of the LAToken, that supports minting and inflation
contract LATokenMintable is LATokenBase {
    /// @custom:storage-location erc7201:lagrange.storage.LATokenMintable
    struct MintableStorage {
        uint256 lastMintCheckpoint; // sum of tokens minted since deployment
    }

    // keccak256(abi.encode(uint256(keccak256("lagrange.storage.LATokenMintable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MINTABLE_STORAGE_SLOT =
        0x2219bb684b280dec630467478a4cd2056b205c5189535fe0d80f615f47799400;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public immutable ANNUAL_INFLATION_RATE_PPTT; // parts per ten-thousand
    uint256 public immutable INITIAL_SUPPLY;
    uint256 private immutable DEPLOYMENT_DATETIME;

    event Mint(address indexed to, uint256 amount);

    error ExceedsAllowedInflation();

    /// @notice Constructor for the LATokenMintable contract
    /// @param lzEndpoint The endpoint for the LayerZero protocol
    /// @param inflationRatePPTT The annual inflation rate in parts per ten-thousand
    /// @param initialTreasury The initial supply of the token, minted to the treasury
    /// @dev only the LATokenMintable needs to know the initial supply, so that it
    /// can enforce inflation properly
    constructor(
        address lzEndpoint,
        uint256 inflationRatePPTT,
        uint256 initialTreasury
    ) LATokenBase(lzEndpoint) {
        ANNUAL_INFLATION_RATE_PPTT = inflationRatePPTT;
        INITIAL_SUPPLY = initialTreasury;
        DEPLOYMENT_DATETIME = block.timestamp;
    }

    /// @notice Initialize the token
    /// @param defaultAdmin The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param treasury The address that will be granted the MINTER_ROLE
    /// @param initialMintHandler The address that will receive the initial mint
    function initialize(
        address defaultAdmin,
        address treasury,
        address initialMintHandler
    ) external initializer {
        __LATokenBase_init(defaultAdmin);
        _grantRole(MINTER_ROLE, treasury);
        _mint(initialMintHandler, INITIAL_SUPPLY);
    }

    /// @notice Returns the amount of tokens that can be minted
    /// @return mintable The amount of tokens that can be minted
    function availableToMint() public view returns (uint256) {
        MintableStorage storage $ = _getMintableStorage();
        uint256 timeElapsed = block.timestamp - DEPLOYMENT_DATETIME;
        // 4% per year linearized: (supply * rate * seconds_elapsed) / (year_in_seconds * 10000)
        return (
            (INITIAL_SUPPLY * ANNUAL_INFLATION_RATE_PPTT * timeElapsed)
                / (365 days * 10000)
        ) - $.lastMintCheckpoint;
    }

    /// @notice Mints tokens to a specified address
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    /// @dev Caller must have the MINTER_ROLE
    /// @dev The amount of tokens to mint cannot exceed the inflation rate
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (amount > availableToMint()) revert ExceedsAllowedInflation();
        MintableStorage storage $ = _getMintableStorage();
        $.lastMintCheckpoint += amount;
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /// @notice Gets the storage struct
    /// @return $ The storage struct
    function _getMintableStorage()
        private
        pure
        returns (MintableStorage storage $)
    {
        bytes32 position = MINTABLE_STORAGE_SLOT;
        assembly {
            $.slot := position
        }
    }
}

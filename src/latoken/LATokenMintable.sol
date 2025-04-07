// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LATokenBase} from "./LATokenBase.sol";

/// @title LATokenMintable
/// @notice This is the eth mainnet version of the LAToken, that supports minting and inflation
contract LATokenMintable is LATokenBase {
    struct MintableStorage {
        uint256 lastMintCheckpoint; // sum of tokens minted since deployment
    }

    // keccak256(abi.encode(uint256(keccak256("LAToken.storage.Mintable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MINTABLE_STORAGE_SLOT =
        0xdf8649829a4265b15de1f1904f50ffe1524a0eb10b8707538514af4f71d43800;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant ANNUAL_INFLATION_RATE = 4; // 4%
    uint256 public immutable INITIAL_SUPPLY;
    uint256 private immutable DEPLOYMENT_DATETIME;

    error ExceedsAllowedInflation();
    error InitialTreasuryTooLarge();

    constructor(address lzEndpoint, uint256 initialSupply)
        LATokenBase(lzEndpoint)
    {
        INITIAL_SUPPLY = initialSupply;
        DEPLOYMENT_DATETIME = block.timestamp;
    }

    /// @notice Initialize the token
    /// @param defaultAdmin The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param treasury The address that will be granted the MINTER_ROLE
    /// @param merkleRoot The merkle root of the airdrop, optional
    /// @param initialTreasurySupply The initial amount in the treasury
    function initialize(
        address defaultAdmin,
        address treasury,
        bytes32 merkleRoot,
        uint256 initialTreasurySupply
    ) external initializer {
        if (initialTreasurySupply > INITIAL_SUPPLY) {
            revert InitialTreasuryTooLarge();
        }
        __LATokenBase_init(defaultAdmin, merkleRoot);
        _grantRole(MINTER_ROLE, treasury);
        _mint(treasury, initialTreasurySupply);
    }

    /// @notice Returns the amount of tokens that can be minted
    /// @return mintable The amount of tokens that can be minted
    function availableToMint() public view returns (uint256) {
        MintableStorage storage $ = _getMintableStorage();
        uint256 timeElapsed = block.timestamp - DEPLOYMENT_DATETIME;
        // 4% per year linearized: (supply * rate * seconds_elapsed) / (year_in_seconds * 10000)
        return (
            (INITIAL_SUPPLY * ANNUAL_INFLATION_RATE * timeElapsed)
                / (365 days * 100)
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

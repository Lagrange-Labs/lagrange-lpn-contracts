// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LPNClientV0} from "../LPNClientV0.sol";
import {ILPNRegistry, OperationType} from "../../interfaces/ILPNRegistry.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AirdropNFTCrosschain is LPNClientV0 {
    // Fill these in with the values that match the deployed NFT contract you want to query:
    address public constant LLOONS_NFT_ADDRESS = address(0); /* Change Me */
    uint256 public constant BALANCES_STORAGE_SLOT = 3; /* Change Me */
    uint256 public constant BALANCES_SIZE_SLOT = 6; /* Change Me */

    // Use this to store context from the request for processing the result in the callback
    mapping(uint256 requestId => RequestMetadata request) public requests;

    struct RequestMetadata {
        address queriedHolder;
        uint96 queriedBlockNumber;
    }

    constructor(ILPNRegistry lpnRegistry) LPNClientV0(lpnRegistry) {}

    // This function is used to register the storage slots of the LagrangeLoonsNFT contract with the LPN registry.
    // It registers the storage slot of the _balances mapping at slot 3 and the numOwners variable at slot 6.
    function lpnRegister() external {
        lpnRegistry.register(
            LLOONS_NFT_ADDRESS, BALANCES_STORAGE_SLOT, BALANCES_SIZE_SLOT
        );
    }

    // This function is used to query the balance of a specific holder at a specific block.
    // It submits a request to the LPN registry to calculate the average balance of the holder at the specified block.
    function queryHolder(address holder) external {
        uint256 blockSnapshot = block.number - 10;

        // Query avg balance of holder 10 blocks ago
        // If result > 0, address held the NFT at that time
        uint256 requestId = lpnRegistry.request(
            address(this),
            bytes32(uint256(uint160(holder))),
            blockSnapshot,
            blockSnapshot,
            OperationType.AVERAGE
        );

        // We can store the requestID if we need to access other data in the callback
        requests[requestId] = RequestMetadata({
            queriedHolder: holder,
            queriedBlockNumber: uint96(blockSnapshot)
        });
    }

    // This function is called by the LPN registry to provide the result of our query above.
    // It sends an airdrop of a token if the address is an NFT holder.
    function processCallback(uint256 requestId, uint256 result)
        internal
        override
    {
        // Process result:
        bool isHolder = result > 0;

        // Take some action based on the result:
        RequestMetadata memory req = requests[requestId];
        if (isHolder) {
            airdropTokens(req.queriedHolder, 10_000);
        }
    }

    function airdropTokens(address holder, uint256 amount) private {}
}

contract LagrangeLoonsNFT is ERC721 {
    // It is important to register the correct storage slot of the mapping you want to query.
    // The `_balances` mapping is in storage slot 3 in the OpenZeppelin ERC721 implementation:
    //     `mapping(address => uint256) private _balances;`

    // This variable keeps track of the number of unique owners of the NFTs.
    // It reflects the number of defined keys in `_balances`
    // It is important to update this variable whenever the balance of a holder changes from 0 to 1+ or vice versa.
    uint256 private _balancesSize; // storage slot 6

    uint256 id;

    constructor() ERC721("Lagrange Loons", "LLOON") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://lagrange.dev/loons/";
    }

    function mint() external {
        if (balanceOf(msg.sender) == 0) {
            unchecked {
                _balancesSize++;
            }
        }
        _mint(msg.sender, id);
        unchecked {
            id++;
        }
    }

    function burn(uint256 id_) external {
        address owner = _ownerOf(id_);
        if (balanceOf(owner) == 1) {
            _balancesSize--;
        }
        _burn(id_);
    }
}

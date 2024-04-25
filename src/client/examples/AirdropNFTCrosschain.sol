// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV0} from "../LPNClientV0.sol";
import {ILPNRegistry} from "../../interfaces/ILPNRegistry.sol";
import {ERC721Enumerable} from
    "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropNFTCrosschain is LPNClientV0 {
    // Fill these in with the values that match the deployed NFT contract you want to query:
    uint256 public constant OWNERS_STORAGE_SLOT = 2; /* Change Me */
    uint256 public constant OWNERS_SIZE_SLOT = 8; /* Change Me */

    address public lloons;

    // Use this to store context from the request for processing the result in the callback
    mapping(uint256 requestId => RequestMetadata request) public requests;

    struct RequestMetadata {
        address queriedHolder;
        uint96 queriedBlockNumber;
    }

    constructor(ILPNRegistry lpnRegistry, LagrangeLoonsNFT lloons_)
        LPNClientV0(lpnRegistry)
    {
        lloons = address(lloons_);
    }

    // This function is used to register the storage slots of the LagrangeLoonsNFT contract with the LPN registry.
    function lpnRegister() external {
        lpnRegistry.register(lloons, OWNERS_STORAGE_SLOT, OWNERS_SIZE_SLOT);
    }

    // This function is used to query the nft token ids of a specific holder over a range of blocks.
    // It submits a request to the LPN registry to select the cumulative token ids owned by the holder in the block range.
    function queryHolder(
        address holder,
        uint256 startBlock,
        uint256 endBlock,
        uint256 offset
    ) external payable {
        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            address(lloons),
            bytes32(uint256(uint160(holder))),
            startBlock,
            endBlock,
            offset
        );

        // We can store the requestID if we need to access other data in the callback
        requests[requestId] = RequestMetadata({
            queriedHolder: holder,
            queriedBlockNumber: uint96(endBlock)
        });
    }

    // This function is called by the LPN registry to provide the result of our query above.
    // It sends an airdrop of a token if the address is an NFT holder.
    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        override
    {
        // Process result:
        bool isHolder = results.length > 0;

        // Take some action based on the result:
        RequestMetadata memory req = requests[requestId];
        if (isHolder) {
            airdropTokens(req.queriedHolder, 10_000);
        }
    }

    function airdropTokens(address holder, uint256 amount) private {}
}

contract LagrangeLoonsNFT is ERC721Enumerable, Ownable {
    // It is important to register the correct storage slot of the mapping you want to query.
    // The `_owners` mapping is in storage slot 2 in the OpenZeppelin ERC721 implementation:
    //     `mapping(uint256 => address) private _onwers;`

    uint256 id;

    constructor() ERC721("Lagrange Loons", "LLOON") Ownable(msg.sender) {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://lagrange.dev/loons/";
    }

    function mint() external {
        _mint(msg.sender, id);
        unchecked {
            id++;
        }
    }

    function burn(uint256 id_) external {
        _burn(id_);
    }
}

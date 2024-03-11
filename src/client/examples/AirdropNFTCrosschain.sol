// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LPNClientV0} from "../LPNClientV0.sol";
import {ILPNRegistry, OperationType} from "../../interfaces/ILPNRegistry.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AirdropNFTCrosschain is LPNClientV0 {
    mapping(uint256 requestId => RequestMetadata request) requests;
    address public constant LLOONS_NFT_ADDRESS = address(0);

    struct RequestMetadata {
        address queriedHolder;
        uint96 queriedBlockNumber;
    }

    constructor(ILPNRegistry lpnRegistry) LPNClientV0(lpnRegistry) {}

    function lpnRegister() external {
        lpnRegistry.register(LLOONS_NFT_ADDRESS, 3, 6);
    }

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
    // _balances mapping is at slot 3: `mapping(address owner => uint256) private _balances;`
    uint256 numOwners; // storage slot 6
    uint256 id;

    constructor() ERC721("Lagrange Loons", "LLOON") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://lagrange.dev/loons/";
    }

    function mint() external {
        if (balanceOf(msg.sender) == 0) {
            unchecked {
                numOwners++;
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
            numOwners--;
        }
        _burn(id_);
    }
}

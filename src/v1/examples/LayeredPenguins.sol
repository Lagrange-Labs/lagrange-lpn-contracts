// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {
    ERC721Enumerable,
    ERC721
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {L1BlockNumber} from "../../utils/L1Block.sol";
import {
    LPNClientV1,
    ILPNRegistryV1,
    QueryOutput,
    QueryErrorCode,
    QueryExecutionError
} from "../client/SDK.sol";

/// @notice Refer to docs page https://lagrange-labs.gitbook.io/lagrange-v2-1/zk-coprocessor/testnet-euclid-developer-docs/example-nft-mint-whitelist-on-l2-with-pudgy-penguins
contract LayeredPenguins is LPNClientV1, ERC721Enumerable {
    /// SELECT AVG(key) FROM pudgy_penguins_owners WHERE value = $1;
    bytes32 public constant SELECT_PUDGY_PENGUINS_QUERY_HASH =
        0xb4ae7462039ec325e1fc805a91fb35c9505f350e609d4d53e1c6e4f3dbfe8997;
    string public constant PUDGY_METADATA_URI =
        "ipfs://bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/";

    struct MintRequest {
        address sender;
    }

    struct Row {
        uint256 tokenId;
    }

    mapping(uint256 requestId => MintRequest request) public mintRequests;

    constructor(ILPNRegistryV1 lpnRegistry_)
        ERC721("Layered Penguins", "LPDGY")
    {
        LPNClientV1._initialize(lpnRegistry_);
    }

    function _baseURI() internal pure override returns (string memory) {
        return PUDGY_METADATA_URI;
    }

    function requestMint() external payable {
        uint256 requestId = queryPudgyPenguins();
        mintRequests[requestId] = MintRequest({sender: msg.sender});
    }

    function queryPudgyPenguins() private returns (uint256) {
        bytes32[] memory placeholders = new bytes32[](1);
        placeholders[0] = bytes32(bytes20(msg.sender));

        return lpnRegistry.request{value: lpnRegistry.gasFee()}(
            SELECT_PUDGY_PENGUINS_QUERY_HASH,
            placeholders,
            L1BlockNumber(),
            L1BlockNumber()
        );
    }

    function processCallback(uint256 requestId, QueryOutput memory result)
        internal
        override
    {
        MintRequest memory req = mintRequests[requestId];

        for (uint256 i = 0; i < result.rows.length; i++) {
            Row memory row = abi.decode(result.rows[i], (Row));

            if (ownerOf(row.tokenId) == address(0)) {
                _mint(req.sender, row.tokenId);
            }
        }

        delete mintRequests[requestId];
    }
}

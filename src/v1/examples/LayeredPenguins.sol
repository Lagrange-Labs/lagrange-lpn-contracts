// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LPNClientV1} from "../client/LPNClientV1.sol";
import {ILPNRegistryV1} from "../interfaces/ILPNRegistryV1.sol";
import {
    ERC721Enumerable,
    ERC721
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {L1BlockNumber} from "../../utils/L1Block.sol";
import {Groth16VerifierExtensions} from "../Groth16VerifierExtensions.sol";

/// @notice Refer to docs page https://lagrange-labs.gitbook.io/lagrange-v2-1/zk-coprocessor/testnet-euclid-developer-docs/example-nft-mint-whitelist-on-l2-with-pudgy-penguins
contract LayeredPenguins is LPNClientV1, ERC721Enumerable {
    /// SELECT key FROM pudgy_penguins_owners WHERE value = $1;
    bytes32 public constant SELECT_PUDGY_PENGUINS_QUERY_HASH =
        0xb4ae7462039ec325e1fc805a91fb35c9505f350e609d4d53e1c6e4f3dbfe8997;
    string public constant PUDGY_METADATA_URI =
        "ipfs://bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/";

    uint256 id;

    struct MintRequest {
        address sender;
    }

    struct Row {
        uint256 tokenId;
    }

    mapping(uint256 requestId => MintRequest request) public mintRequests;

    constructor(ILPNRegistryV1 lpnRegistry_)
        ERC721("Layered Penguins", "LPDGY")
        LPNClientV1(lpnRegistry_)
    {}

    function _baseURI() internal pure override returns (string memory) {
        return PUDGY_METADATA_URI;
    }

    function requestMint() external payable {
        uint256 requestId = queryPudgyPenguins();
        mintRequests[requestId] = MintRequest({sender: msg.sender});
    }

    function queryPudgyPenguins() private returns (uint256) {
        uint256[] memory placeholders = new uint256[](1);
        placeholders[0] = uint256(uint160(msg.sender));

        // TODO: Limit + Offset
        return lpnRegistry.request{value: lpnRegistry.gasFee()}(
            SELECT_PUDGY_PENGUINS_QUERY_HASH,
            placeholders,
            L1BlockNumber(),
            L1BlockNumber()
        );
    }

    function processCallback(
        uint256 requestId,
        Groth16VerifierExtensions.QueryOutput memory result
    ) internal override {
        bool isPudgyHolder = false;
        for (uint256 i = 0; i < result.rows.length; i++) {
            Row memory row = abi.decode(result.rows[i], (Row));

            isPudgyHolder = true;
        }

        if (isPudgyHolder) {
            MintRequest memory req = mintRequests[requestId];
            _mint(req.sender, id);

            id++;
        }

        delete mintRequests[requestId];
    }
}

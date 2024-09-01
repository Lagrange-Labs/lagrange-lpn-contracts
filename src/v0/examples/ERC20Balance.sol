// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV0} from "../client/LPNClientV0.sol";
import {ILPNRegistry} from "../interfaces/ILPNRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {QueryParams} from "../QueryParams.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract ERC20Balance is LPNClientV0 {
    using QueryParams for QueryParams.ERC20QueryParams;

    // Fill these in with the values that match the deployed ERC20 contract you want to query:
    uint256 public constant BALANCEOF_STORAGE_SLOT = 4; /* Change Me */

    address public erc20;

    // Use this to store context from the request for processing the result in the callback
    mapping(uint256 requestId => RequestMetadata request) public requests;

    struct RequestMetadata {
        address holder;
        uint96 startBlock;
        uint248 endBlock;
        QueryType queryType;
    }

    enum QueryType {
        Proportionate,
        Cumulative
    }

    constructor(ILPNRegistry lpnRegistry, IERC20 erc20_)
        LPNClientV0(lpnRegistry)
    {
        erc20 = address(erc20_);
    }

    // This function is used to query the SUM(balance * rewardsRate / totalSupply) of a specific holder over a range of blocks.
    // It submits a request to the LPN registry, which triggers the network to compute the result + proof and send back the verified result in the callback below.
    function queryCumulativeProportionateBalance(
        address holder,
        uint256 startBlock,
        uint256 endBlock,
        uint256 rewardsRate
    ) external payable {
        uint256 requestId = queryBalance(
            QueryParams.newERC20QueryParams(holder, uint88(rewardsRate)),
            startBlock,
            endBlock
        );

        requests[requestId] = RequestMetadata({
            holder: holder,
            startBlock: uint96(startBlock),
            endBlock: uint248(endBlock),
            queryType: QueryType.Proportionate
        });
    }

    // This function is used to query the SUM(balance) of a specific holder over a range of blocks.
    // It submits a request to the LPN registry, which triggers the network to compute the result + proof and send back the verified result in the callback below.
    function queryCumulativeBalance(
        address holder,
        uint256 startBlock,
        uint256 endBlock
    ) external payable {
        uint256 requestId = queryBalance(
            QueryParams.newERC20QueryParams(holder, uint88(1)),
            startBlock,
            endBlock
        );

        requests[requestId] = RequestMetadata({
            holder: holder,
            startBlock: uint96(startBlock),
            endBlock: uint248(endBlock),
            queryType: QueryType.Cumulative
        });
    }

    function queryBalance(
        QueryParams.ERC20QueryParams memory params,
        uint256 startBlock,
        uint256 endBlock
    ) private returns (uint256) {
        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            erc20, params.toBytes32(), startBlock, endBlock
        );

        return requestId;
    }

    // This function is called by the LPN registry to provide the result of our query above.
    // It sends an airdrop of a separate token based on the query result.
    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        override
    {
        // Get our context needed to process the result
        RequestMetadata memory req = requests[requestId];
        uint256 blockRange = (req.endBlock - req.startBlock) + 1;
        uint256 result = results[0];

        // We are handling 2 different types of queries in 2 different ways in the same contract
        if (req.queryType == QueryType.Proportionate) {
            // This is their average proportion of the totalSupply over the queried block range multiplied by the specified rewards rate
            uint256 proportionateBalance = result / blockRange;

            airdropTokens(req.holder, proportionateBalance);
        } else {
            // This is their average balance over the queried block range
            uint256 avgBalance = result / blockRange;

            airdropTokens(req.holder, avgBalance);
        }
    }

    function airdropTokens(address holder, uint256 amount) private {}
}

contract TestERC20 is MockERC20 {
    // It is important to register the correct storage slot of the mapping you want to query.
    // The `_balanceOf` mapping is in storage slot 4 in the forge-std MockERC20 implementation:
    //     `mapping(address => uint256) private _balanceOf;`

    constructor() {
        MockERC20.initialize("Test ERC20", "LERC20", 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

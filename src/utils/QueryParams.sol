// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Groth16VerifierExtensions} from "../Groth16VerifierExtensions.sol";

uint8 constant NFT_QUERY_IDENTIFIER =
    uint8(Groth16VerifierExtensions.QUERY_IDENTIFIER_NFT);

uint8 constant ERC20_QUERY_IDENTIFIER =
    uint8(Groth16VerifierExtensions.QUERY_IDENTIFIER_ERC20);

/// @notice Error thrown when specifying params with an unknown query identifier.
error UnsupportedParams();

/// @title Helper lib for constructing params to queries
library QueryParams {
    /// @notice Calldata parameters for an NFT Query
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param offset The offset value for pagination or data fetching
    struct NFTQueryParams {
        uint8 identifier;
        address userAddress;
        uint88 offset;
    }

    /// @notice Calldata parameters for an ERC20 Query
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param rewardsRate The rewards rate for the ERC20 token
    struct ERC20QueryParams {
        uint8 identifier;
        address userAddress;
        uint88 rewardsRate;
    }

    /// @notice Combined structure of all possible query parameters
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param rewardsRate The rewards rate for the ERC20 token
    /// @param offset The offset value for pagination or data fetching
    struct CombinedParams {
        uint8 identifier;
        address userAddress;
        uint88 rewardsRate;
        uint256 offset;
    }

    function newNFTQueryParams(address userAddress, uint88 offset)
        internal
        pure
        returns (NFTQueryParams memory)
    {
        return NFTQueryParams(NFT_QUERY_IDENTIFIER, userAddress, offset);
    }

    function newERC20QueryParams(address userAddress, uint88 rewardsRate)
        internal
        pure
        returns (ERC20QueryParams memory)
    {
        return
            ERC20QueryParams(ERC20_QUERY_IDENTIFIER, userAddress, rewardsRate);
    }

    function toBytes32(NFTQueryParams memory params)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(
            uint256(params.identifier) << 248
                | uint256(uint160(params.userAddress)) << 88
                | uint256(params.offset)
        );
    }

    function toBytes32(ERC20QueryParams memory params)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(
            uint256(params.identifier) << 248
                | uint256(uint160(params.userAddress)) << 88
                | uint256(params.rewardsRate)
        );
    }

    function fromBytes32(NFTQueryParams memory, bytes32 params)
        internal
        pure
        returns (NFTQueryParams memory)
    {
        uint8 identifier = uint8(uint256(params) >> 248);
        address userAddress = address(uint160(uint256(params) >> 88));
        uint88 offset = uint88(uint256(params));
        return NFTQueryParams(identifier, userAddress, offset);
    }

    function fromBytes32(ERC20QueryParams memory, bytes32 params)
        internal
        pure
        returns (ERC20QueryParams memory)
    {
        uint8 identifier = uint8(uint256(params) >> 248);
        address userAddress = address(uint160(uint256(params) >> 88));
        uint88 rewardsRate = uint88(uint256(params));
        return ERC20QueryParams(identifier, userAddress, rewardsRate);
    }

    /// @notice Parse structured values from 32 bytes of params
    /// @param params 32-bytes of abi-encoded params values
    function combinedFromBytes32(bytes32 params)
        internal
        pure
        returns (CombinedParams memory)
    {
        CombinedParams memory cp = CombinedParams({
            identifier: uint8(bytes1(params[0])),
            userAddress: address(0),
            rewardsRate: uint88(0),
            offset: uint88(0)
        });

        if (cp.identifier == NFT_QUERY_IDENTIFIER) {
            NFTQueryParams memory p;
            p = fromBytes32(p, params);

            cp.userAddress = p.userAddress;
            cp.offset = p.offset;

            return cp;
        }

        if (cp.identifier == ERC20_QUERY_IDENTIFIER) {
            ERC20QueryParams memory p;
            p = fromBytes32(p, params);

            cp.userAddress = p.userAddress;
            cp.rewardsRate = p.rewardsRate;

            return cp;
        }

        revert UnsupportedParams();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/// @notice This contract defines the multi-sigs for each chain
abstract contract MultiSigs {
    mapping(uint256 => address) public engMultiSigs;
    mapping(uint256 => address) public financeMultiSigs;

    constructor() {
        // Mainnet
        engMultiSigs[1] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Base
        engMultiSigs[8453] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[8453] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Mantle
        engMultiSigs[5000] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[5000] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Holesky
        engMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        financeMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        // Sepolia
        engMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        financeMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        // Fraxtal Testnet
        engMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        financeMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        // Scroll Sepolia
        engMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        financeMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        // Base Sepolia
        engMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        financeMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        // Polygon zkEVM
        engMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
    }

    function getEngMultiSig(uint256 chainId) internal view returns (address) {
        address addr = engMultiSigs[chainId];
        require(addr != address(0), "Eng multi-sig not found");
        return addr;
    }

    function getFinanceMultiSig(uint256 chainId)
        internal
        view
        returns (address)
    {
        address addr = financeMultiSigs[chainId];
        require(addr != address(0), "Finance multi-sig not found");
        return addr;
    }
}

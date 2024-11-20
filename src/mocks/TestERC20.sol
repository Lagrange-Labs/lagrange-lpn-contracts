// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract TestERC20 is MockERC20 {
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

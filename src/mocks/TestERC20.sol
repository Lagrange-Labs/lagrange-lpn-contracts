// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    uint256 public s_transferFee;

    constructor() ERC20("Test ERC20", "TERC20") {}

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(amount >= s_transferFee, "transfer fee");
        _burn(msg.sender, s_transferFee);
        return super.transfer(to, amount - s_transferFee);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(amount >= s_transferFee, "transfer fee");
        _burn(from, s_transferFee);
        return super.transferFrom(from, to, amount - s_transferFee);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function setTransferFee(uint256 fee) external {
        s_transferFee = fee;
    }
}

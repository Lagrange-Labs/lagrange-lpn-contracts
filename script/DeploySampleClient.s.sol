// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {SampleClientV0} from "../src/SampleClientV0.sol";
import {ILPNRegistry} from "../src/interfaces/ILPNRegistry.sol";

contract DeployLPNRegistry is BaseScript {
    SampleClientV0 client;

    function run() external returns (SampleClientV0) {
        client = deploy(salt);
        assertions();
        print("SampleClientV0", address(client));
        return client;
    }

    function deploy(bytes32 _salt)
        public
        broadcaster
        returns (SampleClientV0)
    {
        // TODO: Fill in lpnRegistry address
        return new SampleClientV0{salt: _salt}(ILPNRegistry(address(0)));
    }

    function assertions() private view {}
}

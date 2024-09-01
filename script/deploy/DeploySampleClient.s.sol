// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {SampleClientV0} from "../../test/v0/SampleClientV0.sol";
import {ILPNRegistry} from "../../src/v0/interfaces/ILPNRegistry.sol";

contract DeploySampleClient is BaseScript {
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
        return
            new SampleClientV0{salt: _salt}(ILPNRegistry(getDeployedRegistry()));
    }

    function assertions() private view {}
}

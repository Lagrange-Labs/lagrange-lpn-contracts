// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {NotAuthorized} from "../../src/utils/OwnableWhitelist.sol";
import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {ZKMRServiceManager} from "../../src/eigenlayer/ZKMRServiceManager.sol";
import {
    Quorum,
    StrategyParams,
    IZKMRStakeRegistry,
    PublicKey
} from "../../src/eigenlayer/interfaces/IZKMRStakeRegistry.sol";
import {IAVSDirectory} from
    "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

contract MockAVSDirectory {
    function updateAVSMetadataURI(string memory _metadataURI) external {
        // Mock behavior here
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry calldata operatorSignature
    ) external {
        // Mock behavior here
    }

    function deregisterOperatorFromAVS(address operator) external {
        // Mock behavior here
    }
}

// contract MockStakeRegistry is IZKMRStakeRegistry {
// Quorum public override quorum;
//
// function setQuorum(Quorum memory _quorum) public {
//     quorum = _quorum;
// }
// }

contract ZKMRServiceManagerTest is Test {
    ZKMRServiceManager serviceManager;

    IAVSDirectory mockAVSDirectory =
        IAVSDirectory(address(new MockAVSDirectory()));

    IZKMRStakeRegistry mockStakeRegistry =
        IZKMRStakeRegistry(makeAddr("stake-registry"));

    address owner = makeAddr("owner");
    address notOwner = makeAddr("not-owner");
    address operator = makeAddr("operator");

    function setUp() public {
        serviceManager = new ZKMRServiceManager();
        serviceManager.initialize(mockAVSDirectory, mockStakeRegistry, owner);
    }

    function testInitialSetup() public view {
        assertEq(serviceManager.avsDirectory(), address(mockAVSDirectory));
        assertEq(
            address(serviceManager.stakeRegistry()), address(mockStakeRegistry)
        );
    }

    function testOnlyOwnerCanUpdateAVSMetadataURI() public {
        string memory testURI = "https://example.com/newuri";
        hoax(owner);
        serviceManager.updateAVSMetadataURI(testURI);

        hoax(notOwner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        serviceManager.updateAVSMetadataURI(testURI);
    }

    function testRegisterOperatorToAVS() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        hoax(address(mockStakeRegistry));
        serviceManager.registerOperatorToAVS(operator, operatorSignature);

        hoax(owner);
        vm.expectRevert();
        serviceManager.registerOperatorToAVS(operator, operatorSignature);
    }

    function testDeregisterOperatorFromAVS() public {
        hoax(address(mockStakeRegistry));
        serviceManager.deregisterOperatorFromAVS(operator);

        vm.expectRevert(NotAuthorized.selector);
        serviceManager.deregisterOperatorFromAVS(operator);
    }
}

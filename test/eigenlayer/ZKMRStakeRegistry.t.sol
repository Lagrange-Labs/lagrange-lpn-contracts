// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";

import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from
    "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {NotAuthorized} from "../../src/utils/OwnableWhitelist.sol";

import {ZKMRStakeRegistry} from "../../src/eigenlayer/ZKMRStakeRegistry.sol";
import {
    Quorum,
    StrategyParams,
    IZKMRStakeRegistry,
    PublicKey
} from "../../src/eigenlayer/interfaces/IZKMRStakeRegistry.sol";

contract MockServiceManager {
    // solhint-disable-next-line
    function deregisterOperatorFromAVS(address) external {}

    function registerOperatorToAVS(
        address,
        ISignatureUtils.SignatureWithSaltAndExpiry memory // solhint-disable-next-line
    ) external {}
}

contract MockDelegationManager {
    function operatorShares(address, address) external pure returns (uint256) {
        return 1000; // Return a dummy value for simplicity
    }

    function getOperatorShares(address, address[] memory strategies)
        external
        pure
        returns (uint256[] memory)
    {
        uint256[] memory response = new uint256[](strategies.length);
        for (uint256 i; i < strategies.length; i++) {
            response[i] = 1000;
        }
        return response; // Return a dummy value for simplicity
    }
}

contract ZKMRStakeRegistrySetup is Test {
    MockDelegationManager public mockDelegationManager;
    MockServiceManager public mockServiceManager;
    IStrategy mockStrategy = IStrategy(makeAddr("mock-strategy"));

    address owner = makeAddr("owner");
    address notOwner = makeAddr("not-owner");

    address internal operator1 = makeAddr("operator1");
    address internal operator2 = makeAddr("operator2");
    address internal notOperator = makeAddr("notOperator");

    function setUp() public virtual {
        mockDelegationManager = new MockDelegationManager();
        mockServiceManager = new MockServiceManager();
    }
}

contract ZKMRStakeRegistryTest is ZKMRStakeRegistrySetup {
    ZKMRStakeRegistry public registry;
    PublicKey public publicKey = PublicKey({x: 1, y: 1});

    function setUp() public virtual override {
        super.setUp();

        Quorum memory quorum = Quorum({strategies: new StrategyParams[](1)});
        quorum.strategies[0] = StrategyParams({
            strategy: IStrategy(makeAddr("initial-mock-strategy")),
            multiplier: 10_000
        });

        registry = new ZKMRStakeRegistry();
        registry.initialize(address(mockDelegationManager), quorum, owner);

        startHoax(owner);
        registry.setServiceManager(address(mockServiceManager));

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        startHoax(owner);
        registry.addToWhitelist(operators);

        startHoax(operator1);
        registry.registerOperator(publicKey, operatorSignature);

        startHoax(operator2);
        registry.registerOperator(publicKey, operatorSignature);

        vm.stopPrank();
    }

    function testBlacklistOperator() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        hoax(owner);
        registry.toggleWhitelist(notOperator);

        hoax(notOperator);
        registry.registerOperator(publicKey, signature);
        hoax(notOperator);
        registry.deregisterOperator();
        hoax(owner);
        registry.toggleWhitelist(notOperator);

        hoax(notOperator);
        vm.expectRevert(NotAuthorized.selector);
        registry.registerOperator(publicKey, signature);
        assertFalse(registry.isRegistered(notOperator));
    }

    function testRegisterOperator() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        uint256 totalOperatorsBefore = registry.totalOperators();

        hoax(owner);
        registry.toggleWhitelist(notOperator);

        hoax(notOperator);
        vm.expectEmit(true, true, true, true);
        emit IZKMRStakeRegistry.OperatorRegistered(
            notOperator, address(mockServiceManager), publicKey
        );
        registry.registerOperator(publicKey, signature);

        assertTrue(registry.isRegistered(notOperator));
        assertEq(registry.totalOperators(), totalOperatorsBefore + 1);

        (uint256 publickeyX, uint256 publickeyY) =
            registry.operators(notOperator);
        assertEq(publickeyX, publicKey.x);
        assertEq(publickeyY, publicKey.y);
    }

    function testRegisterOperator_RevertsWhenNotWhitelisted() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        hoax(notOperator);
        vm.expectRevert(NotAuthorized.selector);
        registry.registerOperator(publicKey, signature);
        assertFalse(registry.isRegistered(notOperator));
    }

    function testRegisterOperator_RevertsWithAlreadyRegistered() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        vm.expectRevert(IZKMRStakeRegistry.OperatorAlreadyRegistered.selector);
        hoax(operator1);
        registry.registerOperator(publicKey, signature);
    }

    function testRegisterOperator_RevertsWithInvalidPublicKey() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;

        hoax(owner);
        registry.toggleWhitelist(notOperator);

        startHoax(notOperator);
        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.registerOperator(PublicKey({x: 0, y: 1}), signature);

        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.registerOperator(PublicKey({x: 1, y: 0}), signature);

        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.registerOperator(PublicKey({x: 0, y: 0}), signature);
    }

    function testDeregisterOperator() public {
        uint256 totalOperatorsBefore = registry.totalOperators();

        vm.prank(operator1);
        vm.expectEmit(true, true, true, true);
        emit IZKMRStakeRegistry.OperatorDeregistered(
            operator1, address(mockServiceManager)
        );
        registry.deregisterOperator();
        assertEq(registry.totalOperators(), totalOperatorsBefore - 1);
    }

    function testDeregisterOperator_RevertsWithNotRegistered() public {
        vm.prank(notOperator);
        vm.expectRevert(IZKMRStakeRegistry.OperatorNotRegistered.selector);
        registry.deregisterOperator();
    }

    function testUpdateOperatorKey() public {
        PublicKey memory newKey = PublicKey({x: 2, y: 2});

        hoax(operator1);
        vm.expectEmit(true, true, true, true);
        emit IZKMRStakeRegistry.OperatorUpdated(
            operator1, address(mockServiceManager), newKey
        );
        registry.updateOperatorKey(newKey);

        assert(registry.isRegistered(operator1));
        (uint256 newkeyX, uint256 newkeyY) = registry.operators(operator1);
        assertEq(newkeyX, newKey.x);
        assertEq(newkeyY, newKey.y);
    }

    function testUpdateOperatorKey_RevertsWithNotRegistered() public {
        PublicKey memory newKey = PublicKey({x: 2, y: 2});

        vm.prank(notOperator);
        vm.expectRevert(IZKMRStakeRegistry.OperatorNotRegistered.selector);
        registry.updateOperatorKey(newKey);
    }

    function testUpdateOperator_RevertsWithInvalidPublicKey() public {
        startHoax(operator1);
        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.updateOperatorKey(PublicKey({x: 1, y: 0}));

        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.updateOperatorKey(PublicKey({x: 0, y: 1}));

        vm.expectRevert(IZKMRStakeRegistry.InvalidPublicKey.selector);
        registry.updateOperatorKey(PublicKey({x: 0, y: 0}));
    }

    function testUpdateQuorumConfig() public {
        Quorum memory oldQuorum = registry.quorum();
        Quorum memory newQuorum = Quorum({strategies: new StrategyParams[](1)});
        newQuorum.strategies[0] =
            StrategyParams({strategy: mockStrategy, multiplier: 10000});
        vm.expectEmit(true, true, true, true);
        emit IZKMRStakeRegistry.QuorumUpdated(oldQuorum, newQuorum);

        hoax(owner);
        registry.updateQuorumConfig(newQuorum);
    }

    function testUpdateQuorumConfig_SameQuorum() public {
        Quorum memory quorum = registry.quorum();

        hoax(owner);
        registry.updateQuorumConfig(quorum);
    }

    function testUpdateQuorumConfig_RevertsWithInvalidQuorum() public {
        Quorum memory invalidQuorum =
            Quorum({strategies: new StrategyParams[](1)});
        invalidQuorum.strategies[0] = StrategyParams({
            /// TODO: Make mock strategy
            strategy: mockStrategy,
            multiplier: 5_000 // This should cause the update to revert as it's not the total required
        });

        vm.expectRevert(IZKMRStakeRegistry.InvalidQuorum.selector);
        hoax(owner);
        registry.updateQuorumConfig(invalidQuorum);
    }

    function testUpdateQuorumConfig_RevertsWithUnauthorized() public {
        Quorum memory validQuorum =
            Quorum({strategies: new StrategyParams[](1)});
        validQuorum.strategies[0] =
            StrategyParams({strategy: mockStrategy, multiplier: 10_000});

        hoax(notOwner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.updateQuorumConfig(validQuorum);
    }

    function testUpdateQuorumConfig_RevertsWhenDuplicate() public {
        Quorum memory validQuorum =
            Quorum({strategies: new StrategyParams[](2)});
        validQuorum.strategies[0] =
            StrategyParams({strategy: mockStrategy, multiplier: 5_000});

        validQuorum.strategies[1] =
            StrategyParams({strategy: mockStrategy, multiplier: 5_000});

        vm.expectRevert(IZKMRStakeRegistry.NotSorted.selector);
        hoax(owner);
        registry.updateQuorumConfig(validQuorum);
    }

    function testUpdateQuorumConfig_RevertsWithNotSorted() public {
        Quorum memory validQuorum =
            Quorum({strategies: new StrategyParams[](2)});
        validQuorum.strategies[0] =
            StrategyParams({strategy: mockStrategy, multiplier: 5_000});

        validQuorum.strategies[1] =
            StrategyParams({strategy: mockStrategy, multiplier: 5_000});
        vm.expectRevert(IZKMRStakeRegistry.NotSorted.selector);
        hoax(owner);
        registry.updateQuorumConfig(validQuorum);
    }

    function testUpdateQuorumConfig_RevertsWhenOverMultiplierTotal() public {
        Quorum memory validQuorum =
            Quorum({strategies: new StrategyParams[](1)});
        validQuorum.strategies[0] =
            StrategyParams({strategy: mockStrategy, multiplier: 10_001});
        vm.expectRevert(IZKMRStakeRegistry.InvalidQuorum.selector);
        hoax(owner);
        registry.updateQuorumConfig(validQuorum);
    }

    function testUpdateMinimumWeight() public {
        uint256 initialMinimumWeight = registry.minimumWeight();
        uint256 newMinimumWeight = 5000;

        assertEq(initialMinimumWeight, 0); // Assuming initial state is 0

        hoax(owner);
        registry.updateMinimumWeight(newMinimumWeight);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, newMinimumWeight);
    }

    function testUpdateMinimumWeight_RevertsWithUnauthorized() public {
        uint256 newMinimumWeight = 5000;

        hoax(notOwner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.updateMinimumWeight(newMinimumWeight);
    }

    function testUpdateMinimumWeight_WithSameWeight() public {
        uint256 initialMinimumWeight = 5000;

        hoax(owner);
        registry.updateMinimumWeight(initialMinimumWeight);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, initialMinimumWeight);
    }

    function testUpdateMinimumWeight_WithZeroWeight() public {
        uint256 initialMinimumWeight = 5000;

        hoax(owner);
        registry.updateMinimumWeight(initialMinimumWeight);

        uint256 newMinimumWeight = 0;

        hoax(owner);
        registry.updateMinimumWeight(newMinimumWeight);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, newMinimumWeight);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {SplitsReceiver, BeamsConfigImpl, BeamsHub, BeamsHistory, BeamsReceiver, UserMetadata} from "src/BeamsHub.sol";
import {ManagedProxy} from "src/Managed.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, ERC20PresetFixedSupply} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract BeamsHubTest is Test {
    BeamsHub internal beamsHub;
    // The ERC-20 used in all helper functions
    IERC20 internal erc20;
    IERC20 internal defaultErc20;
    IERC20 internal otherErc20;

    // Keys are user ID and ERC-20
    mapping(uint256 => mapping(IERC20 => BeamsReceiver[]))
        internal currBeamsReceivers;
    // Key is user IDs
    mapping(uint256 => SplitsReceiver[]) internal currSplitsReceivers;

    address internal driver = address(1);
    address internal admin = address(2);

    uint32 internal driverId;

    uint256 internal user;
    uint256 internal receiver;
    uint256 internal user1;
    uint256 internal receiver1;
    uint256 internal user2;
    uint256 internal receiver2;
    uint256 internal receiver3;

    bytes internal constant ERROR_NOT_DRIVER = "Callable only by the driver";
    bytes internal constant ERROR_BALANCE_TOO_HIGH = "Total balance too high";
    bytes internal constant ERROR_ERC_20_BALANCE_TOO_LOW =
        "ERC-20 balance too low";

    function setUp() public {
        defaultErc20 = new ERC20PresetFixedSupply(
            "default",
            "default",
            2 ** 128,
            address(this)
        );
        otherErc20 = new ERC20PresetFixedSupply(
            "other",
            "other",
            2 ** 128,
            address(this)
        );
        erc20 = defaultErc20;
        BeamsHub hubLogic = new BeamsHub(10);
        beamsHub = BeamsHub(address(new ManagedProxy(hubLogic, admin)));

        driverId = beamsHub.registerDriver(driver);
        uint256 baseUserId = driverId << 224;
        user = baseUserId + 1;
        user1 = baseUserId + 2;
        user2 = baseUserId + 3;
        receiver = baseUserId + 4;
        receiver1 = baseUserId + 5;
        receiver2 = baseUserId + 6;
        receiver3 = baseUserId + 7;
    }

    function skipToCycleEnd() internal {
        skip(beamsHub.cycleSecs() - (block.timestamp % beamsHub.cycleSecs()));
    }

    function loadBeams(
        uint256 forUser
    ) internal returns (BeamsReceiver[] memory currReceivers) {
        currReceivers = currBeamsReceivers[forUser][erc20];
        assertBeams(forUser, currReceivers);
    }

    function storeBeams(
        uint256 forUser,
        BeamsReceiver[] memory newReceivers
    ) internal {
        assertBeams(forUser, newReceivers);
        delete currBeamsReceivers[forUser][erc20];
        for (uint256 i = 0; i < newReceivers.length; i++) {
            currBeamsReceivers[forUser][erc20].push(newReceivers[i]);
        }
    }

    function loadSplits(
        uint256 forUser
    ) internal returns (SplitsReceiver[] memory currSplits) {
        currSplits = currSplitsReceivers[forUser];
        assertSplits(forUser, currSplits);
    }

    function storeSplits(
        uint256 forUser,
        SplitsReceiver[] memory newReceivers
    ) internal {
        assertSplits(forUser, newReceivers);
        delete currSplitsReceivers[forUser];
        for (uint256 i = 0; i < newReceivers.length; i++) {
            currSplitsReceivers[forUser].push(newReceivers[i]);
        }
    }

    function beamsReceivers()
        internal
        pure
        returns (BeamsReceiver[] memory list)
    {
        list = new BeamsReceiver[](0);
    }

    function beamsReceivers(
        uint256 beamsReceiver,
        uint128 amtPerSec
    ) internal view returns (BeamsReceiver[] memory list) {
        list = new BeamsReceiver[](1);
        list[0] = BeamsReceiver(
            beamsReceiver,
            BeamsConfigImpl.create(
                0,
                uint160(amtPerSec * beamsHub.AMT_PER_SEC_MULTIPLIER()),
                0,
                0
            )
        );
    }

    function beamsReceivers(
        uint256 beamsReceiver1,
        uint128 amtPerSec1,
        uint256 beamsReceiver2,
        uint128 amtPerSec2
    ) internal view returns (BeamsReceiver[] memory list) {
        list = new BeamsReceiver[](2);
        list[0] = beamsReceivers(beamsReceiver1, amtPerSec1)[0];
        list[1] = beamsReceivers(beamsReceiver2, amtPerSec2)[0];
    }

    function setBeams(
        uint256 forUser,
        uint128 balanceFrom,
        uint128 balanceTo,
        BeamsReceiver[] memory newReceivers
    ) internal {
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);
        uint256 balanceBefore = balance();
        uint256 beamsHubBalanceBefore = beamsHubBalance();
        uint256 totalBalanceBefore = totalBalance();
        BeamsReceiver[] memory currReceivers = loadBeams(forUser);

        if (balanceDelta > 0) transferToBeamsHub(uint128(balanceDelta));
        vm.prank(driver);
        int128 realBalanceDelta = beamsHub.setBeams(
            forUser,
            erc20,
            currReceivers,
            balanceDelta,
            newReceivers,
            0,
            0
        );
        if (balanceDelta < 0) withdraw(uint128(-balanceDelta));

        storeBeams(forUser, newReceivers);
        assertEq(realBalanceDelta, balanceDelta, "Invalid real balance delta");
        (, , uint32 updateTime, uint128 actualBalance, ) = beamsHub.beamsState(
            forUser,
            erc20
        );
        assertEq(updateTime, block.timestamp, "Invalid new last update time");
        assertEq(balanceTo, actualBalance, "Invalid beams balance");
        assertBalance(uint256(int256(balanceBefore) - balanceDelta));
        assertBeamsHubBalance(
            uint256(int256(beamsHubBalanceBefore) + balanceDelta)
        );
        assertTotalBalance(uint256(int256(totalBalanceBefore) + balanceDelta));
    }

    function assertBeams(
        uint256 forUser,
        BeamsReceiver[] memory currReceivers
    ) internal {
        (bytes32 actual, , , , ) = beamsHub.beamsState(forUser, erc20);
        bytes32 expected = beamsHub.hashBeams(currReceivers);
        assertEq(actual, expected, "Invalid beams configuration");
    }

    function give(uint256 fromUser, uint256 toUser, uint128 amt) internal {
        uint256 balanceBefore = balance();
        uint256 beamsHubBalanceBefore = beamsHubBalance();
        uint256 totalBalanceBefore = totalBalance();
        uint128 expectedSplittable = splittable(toUser) + amt;

        transferToBeamsHub(amt);
        vm.prank(driver);
        beamsHub.give(fromUser, toUser, erc20, amt);

        assertBalance(balanceBefore - amt);
        assertBeamsHubBalance(beamsHubBalanceBefore + amt);
        assertTotalBalance(totalBalanceBefore + amt);
        assertSplittable(toUser, expectedSplittable);
    }

    function assertGiveReverts(
        uint256 fromUser,
        uint256 toUser,
        uint128 amt,
        bytes memory expectedReason
    ) internal {
        vm.prank(driver);
        vm.expectRevert(expectedReason);
        beamsHub.give(fromUser, toUser, erc20, amt);
    }

    function splitsReceivers()
        internal
        pure
        returns (SplitsReceiver[] memory list)
    {
        list = new SplitsReceiver[](0);
    }

    function splitsReceivers(
        uint256 splitsReceiver,
        uint32 weight
    ) internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](1);
        list[0] = SplitsReceiver(splitsReceiver, weight);
    }

    function splitsReceivers(
        uint256 splitsReceiver1,
        uint32 weight1,
        uint256 splitsReceiver2,
        uint32 weight2
    ) internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](2);
        list[0] = SplitsReceiver(splitsReceiver1, weight1);
        list[1] = SplitsReceiver(splitsReceiver2, weight2);
    }

    function setSplits(
        uint256 forUser,
        SplitsReceiver[] memory newReceivers
    ) internal {
        SplitsReceiver[] memory curr = loadSplits(forUser);
        assertSplits(forUser, curr);

        vm.prank(driver);
        beamsHub.setSplits(forUser, newReceivers);

        storeSplits(forUser, newReceivers);
        assertSplits(forUser, newReceivers);
    }

    function assertSplits(
        uint256 forUser,
        SplitsReceiver[] memory expectedReceivers
    ) internal {
        bytes32 actual = beamsHub.splitsHash(forUser);
        bytes32 expected = beamsHub.hashSplits(expectedReceivers);
        assertEq(actual, expected, "Invalid splits hash");
    }

    function collectAll(uint256 forUser, uint128 expectedAmt) internal {
        collectAll(forUser, expectedAmt, 0);
    }

    function collectAll(
        uint256 forUser,
        uint128 expectedCollected,
        uint128 expectedSplit
    ) internal {
        uint128 receivable = beamsHub.receiveBeamsResult(
            forUser,
            erc20,
            type(uint32).max
        );
        uint32 receivableCycles = beamsHub.receivableBeamsCycles(
            forUser,
            erc20
        );
        receiveBeams(forUser, receivable, receivableCycles);

        split(forUser, expectedCollected - collectable(forUser), expectedSplit);

        collect(forUser, expectedCollected);
    }

    function receiveBeams(
        uint256 forUser,
        uint128 expectedReceivedAmt,
        uint32 expectedReceivedCycles
    ) internal {
        receiveBeams(
            forUser,
            type(uint32).max,
            expectedReceivedAmt,
            expectedReceivedCycles,
            0,
            0
        );
    }

    function receiveBeams(
        uint256 forUser,
        uint32 maxCycles,
        uint128 expectedReceivedAmt,
        uint32 expectedReceivedCycles,
        uint128 expectedAmtAfter,
        uint32 expectedCyclesAfter
    ) internal {
        uint128 expectedTotalAmt = expectedReceivedAmt + expectedAmtAfter;
        uint32 expectedTotalCycles = expectedReceivedCycles +
            expectedCyclesAfter;
        assertReceivableBeamsCycles(forUser, expectedTotalCycles);
        assertReceiveBeamsResult(forUser, type(uint32).max, expectedTotalAmt);
        assertReceiveBeamsResult(forUser, maxCycles, expectedReceivedAmt);

        uint128 receivedAmt = beamsHub.receiveBeams(forUser, erc20, maxCycles);

        assertEq(
            receivedAmt,
            expectedReceivedAmt,
            "Invalid amount received from beams"
        );
        assertReceivableBeamsCycles(forUser, expectedCyclesAfter);
        assertReceiveBeamsResult(forUser, type(uint32).max, expectedAmtAfter);
    }

    function assertReceivableBeamsCycles(
        uint256 forUser,
        uint32 expectedCycles
    ) internal {
        uint32 actualCycles = beamsHub.receivableBeamsCycles(forUser, erc20);
        assertEq(
            actualCycles,
            expectedCycles,
            "Invalid total receivable beams cycles"
        );
    }

    function assertReceiveBeamsResult(
        uint256 forUser,
        uint32 maxCycles,
        uint128 expectedAmt
    ) internal {
        uint128 actualAmt = beamsHub.receiveBeamsResult(
            forUser,
            erc20,
            maxCycles
        );
        assertEq(actualAmt, expectedAmt, "Invalid receivable amount");
    }

    function split(
        uint256 forUser,
        uint128 expectedCollectable,
        uint128 expectedSplit
    ) internal {
        assertSplittable(forUser, expectedCollectable + expectedSplit);
        assertSplitResult(
            forUser,
            expectedCollectable + expectedSplit,
            expectedCollectable
        );
        uint128 collectableBefore = collectable(forUser);

        (uint128 collectableAmt, uint128 splitAmt) = beamsHub.split(
            forUser,
            erc20,
            loadSplits(forUser)
        );

        assertEq(
            collectableAmt,
            expectedCollectable,
            "Invalid collectable amount"
        );
        assertEq(splitAmt, expectedSplit, "Invalid split amount");
        assertSplittable(forUser, 0);
        assertCollectable(forUser, collectableBefore + expectedCollectable);
    }

    function splittable(uint256 forUser) internal view returns (uint128 amt) {
        return beamsHub.splittable(forUser, erc20);
    }

    function assertSplittable(uint256 forUser, uint256 expected) internal {
        uint128 actual = splittable(forUser);
        assertEq(actual, expected, "Invalid splittable");
    }

    function assertSplitResult(
        uint256 forUser,
        uint256 amt,
        uint256 expected
    ) internal {
        (uint128 collectableAmt, uint128 splitAmt) = beamsHub.splitResult(
            forUser,
            loadSplits(forUser),
            uint128(amt)
        );
        assertEq(collectableAmt, expected, "Invalid collectable amount");
        assertEq(splitAmt, amt - expected, "Invalid split amount");
    }

    function collect(uint256 forUser, uint128 expectedAmt) internal {
        assertCollectable(forUser, expectedAmt);
        uint256 balanceBefore = balance();
        uint256 beamsHubBalanceBefore = beamsHubBalance();
        uint256 totalBalanceBefore = totalBalance();

        vm.prank(driver);
        uint128 actualAmt = beamsHub.collect(forUser, erc20);
        withdraw(actualAmt);

        assertEq(actualAmt, expectedAmt, "Invalid collected amount");
        assertCollectable(forUser, 0);
        assertBalance(balanceBefore + expectedAmt);
        assertBeamsHubBalance(beamsHubBalanceBefore - expectedAmt);
        assertTotalBalance(totalBalanceBefore - expectedAmt);
    }

    function collectable(uint256 forUser) internal view returns (uint128 amt) {
        return beamsHub.collectable(forUser, erc20);
    }

    function assertCollectable(uint256 forUser, uint256 expected) internal {
        assertEq(collectable(forUser), expected, "Invalid collectable");
    }

    function totalBalance() internal view returns (uint256) {
        return beamsHub.totalBalance(erc20);
    }

    function assertTotalBalance(uint256 expected) internal {
        assertEq(totalBalance(), expected, "Invalid total balance");
    }

    function transferToBeamsHub(uint256 amt) internal {
        assertBeamsHubBalance(totalBalance());
        erc20.transfer(address(beamsHub), amt);
    }

    function withdraw(uint256 amt) internal {
        uint256 balanceBefore = balance();
        uint256 totalBalanceBefore = totalBalance();
        assertBeamsHubBalance(totalBalanceBefore + amt);

        beamsHub.withdraw(erc20, address(this), amt);

        assertBalance(balanceBefore + amt);
        assertTotalBalance(totalBalanceBefore);
        assertBeamsHubBalance(totalBalanceBefore);
    }

    function balance() internal view returns (uint256) {
        return erc20.balanceOf(address(this));
    }

    function assertBalance(uint256 expected) internal {
        assertEq(balance(), expected, "Invalid balance");
    }

    function beamsHubBalance() internal view returns (uint256) {
        return erc20.balanceOf(address(beamsHub));
    }

    function assertBeamsHubBalance(uint256 expected) internal {
        assertEq(beamsHubBalance(), expected, "Invalid BeamsHub balance");
    }

    function testDoesNotRequireReceiverToBeInitialized() public {
        receiveBeams(receiver, 0, 0);
        split(receiver, 0, 0);
        collect(receiver, 0);
    }

    function testSetBeamsLimitsWithdrawalToBeamsBalance() public {
        uint128 beamsBalance = 10;
        BeamsReceiver[] memory receivers = beamsReceivers();
        uint256 balanceBefore = balance();
        setBeams(user, 0, beamsBalance, receivers);

        vm.prank(driver);
        int128 realBalanceDelta = beamsHub.setBeams(
            user,
            erc20,
            receivers,
            -int128(beamsBalance) - 1,
            receivers,
            0,
            0
        );
        withdraw(uint128(-realBalanceDelta));

        assertEq(
            realBalanceDelta,
            -int128(beamsBalance),
            "Invalid real balance delta"
        );
        (, , , uint128 actualBalance, ) = beamsHub.beamsState(user, erc20);
        assertEq(actualBalance, 0, "Invalid beams balance");
        assertBalance(balanceBefore);
        assertBeamsHubBalance(0);
        assertTotalBalance(0);
    }

    function testUncollectedFundsAreSplitUsingCurrentConfig() public {
        uint32 totalWeight = beamsHub.TOTAL_SPLITS_WEIGHT();
        setSplits(user1, splitsReceivers(receiver1, totalWeight));
        setBeams(user2, 0, 5, beamsReceivers(user1, 5));
        skipToCycleEnd();
        give(user2, user1, 5);
        setSplits(user1, splitsReceivers(receiver2, totalWeight));
        // Receiver1 had 1 second paying 5 per second and was given 5 of which 10 is split
        collectAll(user1, 0, 10);
        // Receiver1 wasn't a splits receiver when user1 was collecting
        collectAll(receiver1, 0);
        // Receiver2 was a splits receiver when user1 was collecting
        collectAll(receiver2, 10);
    }

    function testReceiveSomeBeamsCycles() public {
        // Enough for 3 cycles
        uint128 amt = beamsHub.cycleSecs() * 3;
        skipToCycleEnd();
        setBeams(user, 0, amt, beamsReceivers(receiver, 1));
        skipToCycleEnd();
        skipToCycleEnd();
        skipToCycleEnd();
        receiveBeams({
            forUser: receiver,
            maxCycles: 2,
            expectedReceivedAmt: beamsHub.cycleSecs() * 2,
            expectedReceivedCycles: 2,
            expectedAmtAfter: beamsHub.cycleSecs(),
            expectedCyclesAfter: 1
        });
        collectAll(receiver, amt);
    }

    function testReceiveAllBeamsCycles() public {
        // Enough for 3 cycles
        uint128 amt = beamsHub.cycleSecs() * 3;
        skipToCycleEnd();
        setBeams(user, 0, amt, beamsReceivers(receiver, 1));
        skipToCycleEnd();
        skipToCycleEnd();
        skipToCycleEnd();

        receiveBeams(receiver, beamsHub.cycleSecs() * 3, 3);

        collectAll(receiver, amt);
    }

    function testSqueezeBeams() public {
        skipToCycleEnd();
        // Start beamping
        BeamsReceiver[] memory receivers = beamsReceivers(receiver, 1);
        setBeams(user, 0, 2, receivers);

        // Create history
        uint32 lastUpdate = uint32(block.timestamp);
        uint32 maxEnd = lastUpdate + 2;
        BeamsHistory[] memory history = new BeamsHistory[](1);
        history[0] = BeamsHistory(0, receivers, lastUpdate, maxEnd);
        bytes32 actualHistoryHash = beamsHub.hashBeamsHistory(
            bytes32(0),
            beamsHub.hashBeams(receivers),
            lastUpdate,
            maxEnd
        );
        (, bytes32 expectedHistoryHash, , , ) = beamsHub.beamsState(
            user,
            erc20
        );
        assertEq(
            actualHistoryHash,
            expectedHistoryHash,
            "Invalid history hash"
        );

        // Check squeezableBeams
        skip(1);
        uint128 amt = beamsHub.squeezeBeamsResult(
            receiver,
            erc20,
            user,
            0,
            history
        );
        assertEq(amt, 1, "Invalid squeezable amt before");

        // Squeeze
        vm.prank(driver);
        amt = beamsHub.squeezeBeams(receiver, erc20, user, 0, history);
        assertEq(amt, 1, "Invalid squeezed amt");

        // Check squeezableBeams
        amt = beamsHub.squeezeBeamsResult(receiver, erc20, user, 0, history);
        assertEq(amt, 0, "Invalid squeezable amt after");

        // Collect the squeezed amount
        split(receiver, 1, 0);
        collect(receiver, 1);
        skipToCycleEnd();
        collectAll(receiver, 1);
    }

    function testFundsGivenFromUserCanBeCollected() public {
        give(user, receiver, 10);
        collectAll(receiver, 10);
    }

    function testSplitSplitsFundsReceivedFromAllSources() public {
        uint32 totalWeight = beamsHub.TOTAL_SPLITS_WEIGHT();
        // Gives
        give(user2, user1, 1);

        // Beams
        setBeams(user2, 0, 2, beamsReceivers(user1, 2));
        skipToCycleEnd();
        receiveBeams(user1, 2, 1);

        // Splits
        setSplits(receiver2, splitsReceivers(user1, totalWeight));
        give(receiver2, receiver2, 5);
        split(receiver2, 0, 5);

        // Split the received 1 + 2 + 5 = 8
        setSplits(user1, splitsReceivers(receiver1, totalWeight / 4));
        split(user1, 6, 2);
        collect(user1, 6);
    }

    function testEmitUserMetadata() public {
        UserMetadata[] memory userMetadata = new UserMetadata[](2);
        userMetadata[0] = UserMetadata("key 1", "value 1");
        userMetadata[1] = UserMetadata("key 2", "value 2");
        vm.prank(driver);
        beamsHub.emitUserMetadata(user, userMetadata);
    }

    function testBalanceAt() public {
        BeamsReceiver[] memory receivers = beamsReceivers(receiver, 1);
        setBeams(user, 0, 2, receivers);
        uint256 balanceAt = beamsHub.balanceAt(
            user,
            erc20,
            receivers,
            uint32(block.timestamp + 1)
        );
        assertEq(balanceAt, 1, "Invalid balance");
    }

    function testRegisterDriver() public {
        address driverAddr = address(0x1234);
        uint32 nextDriverId = beamsHub.nextDriverId();
        assertEq(
            address(0),
            beamsHub.driverAddress(nextDriverId),
            "Invalid unused driver address"
        );
        assertEq(
            nextDriverId,
            beamsHub.registerDriver(driverAddr),
            "Invalid assigned driver ID"
        );
        assertEq(
            driverAddr,
            beamsHub.driverAddress(nextDriverId),
            "Invalid driver address"
        );
        assertEq(
            nextDriverId + 1,
            beamsHub.nextDriverId(),
            "Invalid next driver ID"
        );
    }

    function testRegisteringDriverForZeroAddressReverts() public {
        vm.expectRevert("Driver registered for 0 address");
        beamsHub.registerDriver(address(0));
    }

    function testUpdateDriverAddress() public {
        assertEq(
            driver,
            beamsHub.driverAddress(driverId),
            "Invalid driver address before"
        );
        address newDriverAddr = address(0x1234);
        vm.prank(driver);
        beamsHub.updateDriverAddress(driverId, newDriverAddr);
        assertEq(
            newDriverAddr,
            beamsHub.driverAddress(driverId),
            "Invalid driver address after"
        );
    }

    function testUpdateDriverAddressRevertsWhenNotCalledByTheDriver() public {
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.updateDriverAddress(driverId, address(1234));
    }

    function testCollectRevertsWhenNotCalledByTheDriver() public {
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.collect(user, erc20);
    }

    function testBeamsInDifferentTokensAreIndependent() public {
        uint32 cycleLength = beamsHub.cycleSecs();
        // Covers 1.5 cycles of beamping
        erc20 = defaultErc20;
        setBeams(
            user,
            0,
            9 * cycleLength,
            beamsReceivers(receiver1, 4, receiver2, 2)
        );

        skipToCycleEnd();
        // Covers 2 cycles of beamping
        erc20 = otherErc20;
        setBeams(user, 0, 6 * cycleLength, beamsReceivers(receiver1, 3));

        skipToCycleEnd();
        // receiver1 had 1.5 cycles of 4 per second
        erc20 = defaultErc20;
        collectAll(receiver1, 6 * cycleLength);
        // receiver1 had 1.5 cycles of 2 per second
        erc20 = defaultErc20;
        collectAll(receiver2, 3 * cycleLength);
        // receiver1 had 1 cycle of 3 per second
        erc20 = otherErc20;
        collectAll(receiver1, 3 * cycleLength);
        // receiver2 received nothing
        erc20 = otherErc20;
        collectAll(receiver2, 0);

        skipToCycleEnd();
        // receiver1 received nothing
        erc20 = defaultErc20;
        collectAll(receiver1, 0);
        // receiver2 received nothing
        erc20 = defaultErc20;
        collectAll(receiver2, 0);
        // receiver1 had 1 cycle of 3 per second
        erc20 = otherErc20;
        collectAll(receiver1, 3 * cycleLength);
        // receiver2 received nothing
        erc20 = otherErc20;
        collectAll(receiver2, 0);
    }

    function testSetBeamsRevertsWhenNotCalledByTheDriver() public {
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.setBeams(
            user,
            erc20,
            beamsReceivers(),
            0,
            beamsReceivers(),
            0,
            0
        );
    }

    function testGiveRevertsWhenNotCalledByTheDriver() public {
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.give(user, 0, erc20, 1);
    }

    function testSetSplitsRevertsWhenNotCalledByTheDriver() public {
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.setSplits(user, splitsReceivers());
    }

    function testEmitUserMetadataRevertsWhenNotCalledByTheDriver() public {
        UserMetadata[] memory userMetadata = new UserMetadata[](1);
        userMetadata[0] = UserMetadata("key", "value");
        vm.expectRevert(ERROR_NOT_DRIVER);
        beamsHub.emitUserMetadata(user, userMetadata);
    }

    function testSetBeamsLimitsTotalBalance() public {
        uint128 maxBalance = uint128(beamsHub.MAX_TOTAL_BALANCE());
        assertTotalBalance(0);
        setBeams(user1, 0, maxBalance, beamsReceivers());
        assertTotalBalance(maxBalance);

        transferToBeamsHub(1);
        vm.prank(driver);
        vm.expectRevert(ERROR_BALANCE_TOO_HIGH);
        beamsHub.setBeams(
            user2,
            erc20,
            beamsReceivers(),
            1,
            beamsReceivers(),
            0,
            0
        );
        withdraw(1);

        setBeams(user1, maxBalance, maxBalance - 1, beamsReceivers());
        assertTotalBalance(maxBalance - 1);
        setBeams(user2, 0, 1, beamsReceivers());
        assertTotalBalance(maxBalance);
    }

    function testSetBeamsRequiresTransferredTokens() public {
        setBeams(user, 0, 2, beamsReceivers());

        vm.prank(driver);
        vm.expectRevert(ERROR_ERC_20_BALANCE_TOO_LOW);
        beamsHub.setBeams(
            user,
            erc20,
            beamsReceivers(),
            1,
            beamsReceivers(),
            0,
            0
        );

        setBeams(user, 2, 3, beamsReceivers());
    }

    function testGiveLimitsTotalBalance() public {
        uint128 maxBalance = uint128(beamsHub.MAX_TOTAL_BALANCE());
        assertTotalBalance(0);
        give(user, receiver1, maxBalance - 1);
        assertTotalBalance(maxBalance - 1);
        give(user, receiver2, 1);
        assertTotalBalance(maxBalance);

        transferToBeamsHub(1);
        vm.prank(driver);
        vm.expectRevert(ERROR_BALANCE_TOO_HIGH);
        beamsHub.give(user, receiver3, erc20, 1);
        withdraw(1);

        collectAll(receiver2, 1);
        assertTotalBalance(maxBalance - 1);
        give(user, receiver3, 1);
        assertTotalBalance(maxBalance);
    }

    function testGiveRequiresTransferredTokens() public {
        give(user, receiver, 2);

        vm.prank(driver);
        vm.expectRevert(ERROR_ERC_20_BALANCE_TOO_LOW);
        beamsHub.give(user, receiver, erc20, 1);

        give(user, receiver, 1);
    }

    function testWithdrawalBelowTotalBalanceReverts() public {
        give(user, receiver, 2);
        transferToBeamsHub(1);

        vm.expectRevert("Withdrawal amount too high");
        beamsHub.withdraw(erc20, address(this), 2);

        withdraw(1);
    }

    modifier canBePausedTest() {
        vm.prank(admin);
        beamsHub.pause();
        vm.expectRevert("Contract paused");
        _;
    }

    function testReceiveBeamsCanBePaused() public canBePausedTest {
        beamsHub.receiveBeams(user, erc20, 1);
    }

    function testSqueezeBeamsCanBePaused() public canBePausedTest {
        beamsHub.squeezeBeams(user, erc20, user, 0, new BeamsHistory[](0));
    }

    function testSplitCanBePaused() public canBePausedTest {
        beamsHub.split(user, erc20, splitsReceivers());
    }

    function testCollectCanBePaused() public canBePausedTest {
        beamsHub.collect(user, erc20);
    }

    function testSetBeamsCanBePaused() public canBePausedTest {
        beamsHub.setBeams(
            user,
            erc20,
            beamsReceivers(),
            1,
            beamsReceivers(),
            0,
            0
        );
    }

    function testGiveCanBePaused() public canBePausedTest {
        beamsHub.give(user, 0, erc20, 1);
    }

    function testSetSplitsCanBePaused() public canBePausedTest {
        beamsHub.setSplits(user, splitsReceivers());
    }

    function testEmitUserMetadataCanBePaused() public canBePausedTest {
        beamsHub.emitUserMetadata(user, new UserMetadata[](0));
    }

    function testRegisterDriverCanBePaused() public canBePausedTest {
        beamsHub.registerDriver(address(0x1234));
    }

    function testUpdateDriverAddressCanBePaused() public canBePausedTest {
        beamsHub.updateDriverAddress(driverId, address(0x1234));
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Beams, BeamsConfig, BeamsHistory, BeamsConfigImpl, BeamsReceiver} from "src/Beams.sol";

contract PseudoRandomUtils {
    bytes32 private seed;
    bool private initialized = false;

    // returns a pseudo-random number between 0 and range
    function random(uint256 range) public returns (uint256) {
        require(initialized, "seed not set for test run");
        seed = keccak256(bytes.concat(seed));
        return uint256(seed) % range;
    }

    function initSeed(bytes32 seed_) public {
        require(initialized == false, "only init seed once per test run");
        seed = seed_;
        initialized = true;
    }
}

contract AssertMinAmtPerSec is Test, Beams {
    constructor(uint32 cycleSecs, uint160 expectedMinAmtPerSec) Beams(cycleSecs, 0) {
        string memory assertMessage =
            string.concat("Invalid minAmtPerSec for cycleSecs ", vm.toString(cycleSecs));
        assertEq(_minAmtPerSec, expectedMinAmtPerSec, assertMessage);
    }
}

contract BeamsTest is Test, PseudoRandomUtils, Beams {
    bytes internal constant ERROR_NOT_SORTED = "Beams receivers not sorted";
    bytes internal constant ERROR_INVALID_DRIPS_LIST = "Invalid current beams list";
    bytes internal constant ERROR_TIMESTAMP_EARLY = "Timestamp before the last update";
    bytes internal constant ERROR_HISTORY_INVALID = "Invalid beams history";
    bytes internal constant ERROR_HISTORY_UNCLEAR = "Entry with hash and receivers";

    // Keys are assetId and userId
    mapping(uint256 => mapping(uint256 => BeamsReceiver[])) internal currReceiversStore;
    uint256 internal defaultAssetId = 1;
    uint256 internal otherAssetId = 2;
    // The asset ID used in all helper functions
    uint256 internal assetId = defaultAssetId;
    uint256 internal sender = 1;
    uint256 internal sender1 = 2;
    uint256 internal sender2 = 3;
    uint256 internal receiver = 4;
    uint256 internal receiver1 = 5;
    uint256 internal receiver2 = 6;
    uint256 internal receiver3 = 7;
    uint256 internal receiver4 = 8;

    constructor() Beams(10, bytes32(uint256(1000))) {
        return;
    }

    function setUp() public {
        skipToCycleEnd();
    }

    function skipToCycleEnd() internal {
        skip(_cycleSecs - (block.timestamp % _cycleSecs));
    }

    function skipTo(uint256 timestamp) internal {
        vm.warp(timestamp);
    }

    function loadCurrReceivers(uint256 userId)
        internal
        returns (BeamsReceiver[] memory currReceivers)
    {
        currReceivers = currReceiversStore[assetId][userId];
        assertBeams(userId, currReceivers);
    }

    function storeCurrReceivers(uint256 userId, BeamsReceiver[] memory newReceivers) internal {
        assertBeams(userId, newReceivers);
        delete currReceiversStore[assetId][userId];
        for (uint256 i = 0; i < newReceivers.length; i++) {
            currReceiversStore[assetId][userId].push(newReceivers[i]);
        }
    }

    function recv() internal pure returns (BeamsReceiver[] memory) {
        return new BeamsReceiver[](0);
    }

    function recv(uint256 userId, uint256 amtPerSec)
        internal
        pure
        returns (BeamsReceiver[] memory receivers)
    {
        return recv(userId, amtPerSec, 0);
    }

    function recv(uint256 userId, uint256 amtPerSec, uint256 amtPerSecFrac)
        internal
        pure
        returns (BeamsReceiver[] memory receivers)
    {
        return recv(userId, amtPerSec, amtPerSecFrac, 0, 0);
    }

    function recv(uint256 userId, uint256 amtPerSec, uint256 start, uint256 duration)
        internal
        pure
        returns (BeamsReceiver[] memory receivers)
    {
        return recv(userId, amtPerSec, 0, start, duration);
    }

    function recv(
        uint256 userId,
        uint256 amtPerSec,
        uint256 amtPerSecFrac,
        uint256 start,
        uint256 duration
    ) internal pure returns (BeamsReceiver[] memory receivers) {
        return recv(userId, 0, amtPerSec, amtPerSecFrac, start, duration);
    }

    function recv(
        uint256 userId,
        uint256 beamId,
        uint256 amtPerSec,
        uint256 amtPerSecFrac,
        uint256 start,
        uint256 duration
    ) internal pure returns (BeamsReceiver[] memory receivers) {
        receivers = new BeamsReceiver[](1);
        uint256 amtPerSecFull = amtPerSec * Beams._AMT_PER_SEC_MULTIPLIER + amtPerSecFrac;
        BeamsConfig config = BeamsConfigImpl.create(
            uint32(beamId), uint160(amtPerSecFull), uint32(start), uint32(duration)
        );
        receivers[0] = BeamsReceiver(userId, config);
    }

    function recv(BeamsReceiver[] memory recv1, BeamsReceiver[] memory recv2)
        internal
        pure
        returns (BeamsReceiver[] memory receivers)
    {
        receivers = new BeamsReceiver[](recv1.length + recv2.length);
        for (uint256 i = 0; i < recv1.length; i++) {
            receivers[i] = recv1[i];
        }
        for (uint256 i = 0; i < recv2.length; i++) {
            receivers[recv1.length + i] = recv2[i];
        }
    }

    function recv(
        BeamsReceiver[] memory recv1,
        BeamsReceiver[] memory recv2,
        BeamsReceiver[] memory recv3
    ) internal pure returns (BeamsReceiver[] memory) {
        return recv(recv(recv1, recv2), recv3);
    }

    function recv(
        BeamsReceiver[] memory recv1,
        BeamsReceiver[] memory recv2,
        BeamsReceiver[] memory recv3,
        BeamsReceiver[] memory recv4
    ) internal pure returns (BeamsReceiver[] memory) {
        return recv(recv(recv1, recv2, recv3), recv4);
    }

    function genRandomRecv(
        uint256 amountReceiver,
        uint160 maxAmtPerSec,
        uint32 maxStart,
        uint32 maxDuration
    ) internal returns (BeamsReceiver[] memory) {
        uint256 inPercent = 100;
        uint256 probMaxEnd = random(inPercent);
        uint256 probStartNow = random(inPercent);
        return genRandomRecv(
            amountReceiver, maxAmtPerSec, maxStart, maxDuration, probMaxEnd, probStartNow
        );
    }

    function genRandomRecv(
        uint256 amountReceiver,
        uint160 maxAmtPerSec,
        uint32 maxStart,
        uint32 maxDuration,
        uint256 probMaxEnd,
        uint256 probStartNow
    ) internal returns (BeamsReceiver[] memory) {
        BeamsReceiver[] memory receivers = new BeamsReceiver[](amountReceiver);
        for (uint256 i = 0; i < amountReceiver; i++) {
            uint256 beamId = random(type(uint32).max + uint256(1));
            uint256 amtPerSec = _minAmtPerSec + random(maxAmtPerSec - _minAmtPerSec);
            uint256 start = random(maxStart);
            if (start % 100 <= probStartNow) {
                start = 0;
            }
            uint256 duration = random(maxDuration);
            if (duration % 100 <= probMaxEnd) {
                duration = 0;
            }
            receivers[i] = recv(i, beamId, 0, amtPerSec, start, duration)[0];
        }
        return receivers;
    }

    function hist() internal pure returns (BeamsHistory[] memory) {
        return new BeamsHistory[](0);
    }

    function hist(BeamsReceiver[] memory receivers, uint32 updateTime, uint32 maxEnd)
        internal
        pure
        returns (BeamsHistory[] memory history)
    {
        history = new BeamsHistory[](1);
        history[0] = BeamsHistory(0, receivers, updateTime, maxEnd);
    }

    function histSkip(bytes32 beamsHash, uint32 updateTime, uint32 maxEnd)
        internal
        pure
        returns (BeamsHistory[] memory history)
    {
        history = hist(recv(), updateTime, maxEnd);
        history[0].beamsHash = beamsHash;
    }

    function hist(uint256 userId) internal returns (BeamsHistory[] memory history) {
        BeamsReceiver[] memory receivers = loadCurrReceivers(userId);
        (,, uint32 updateTime,, uint32 maxEnd) = Beams._beamsState(userId, assetId);
        return hist(receivers, updateTime, maxEnd);
    }

    function histSkip(uint256 userId) internal view returns (BeamsHistory[] memory history) {
        (bytes32 beamsHash,, uint32 updateTime,, uint32 maxEnd) = Beams._beamsState(userId, assetId);
        return histSkip(beamsHash, updateTime, maxEnd);
    }

    function hist(BeamsHistory[] memory history, uint256 userId)
        internal
        returns (BeamsHistory[] memory)
    {
        return hist(history, hist(userId));
    }

    function histSkip(BeamsHistory[] memory history, uint256 userId)
        internal
        view
        returns (BeamsHistory[] memory)
    {
        return hist(history, histSkip(userId));
    }

    function hist(BeamsHistory[] memory history1, BeamsHistory[] memory history2)
        internal
        pure
        returns (BeamsHistory[] memory history)
    {
        history = new BeamsHistory[](history1.length + history2.length);
        for (uint256 i = 0; i < history1.length; i++) {
            history[i] = history1[i];
        }
        for (uint256 i = 0; i < history2.length; i++) {
            history[history1.length + i] = history2[i];
        }
    }

    function drainBalance(uint256 userId, uint128 balanceFrom) internal {
        setBeams(userId, balanceFrom, 0, loadCurrReceivers(userId), 0);
    }

    function setBeams(
        uint256 userId,
        uint128 balanceFrom,
        uint128 balanceTo,
        BeamsReceiver[] memory newReceivers,
        uint256 expectedMaxEndFromNow
    ) internal {
        setBeams(userId, balanceFrom, balanceTo, newReceivers, 0, 0, expectedMaxEndFromNow);
    }

    function setBeams(
        uint256 userId,
        uint128 balanceFrom,
        uint128 balanceTo,
        BeamsReceiver[] memory newReceivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        uint256 expectedMaxEndFromNow
    ) internal {
        (, bytes32 oldHistoryHash,,,) = Beams._beamsState(userId, assetId);
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);

        int128 realBalanceDelta = Beams._setBeams(
            userId,
            assetId,
            loadCurrReceivers(userId),
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2
        );

        assertEq(realBalanceDelta, balanceDelta, "Invalid real balance delta");
        storeCurrReceivers(userId, newReceivers);
        (bytes32 beamsHash, bytes32 historyHash, uint32 updateTime, uint128 balance, uint32 maxEnd)
        = Beams._beamsState(userId, assetId);
        assertEq(
            Beams._hashBeamsHistory(oldHistoryHash, beamsHash, updateTime, maxEnd),
            historyHash,
            "Invalid history hash"
        );
        assertEq(updateTime, block.timestamp, "Invalid new last update time");
        assertEq(balanceTo, balance, "Invalid beams balance");
        assertEq(maxEnd, block.timestamp + expectedMaxEndFromNow, "Invalid max end");
    }

    function maxEndMax() internal view returns (uint32) {
        return type(uint32).max - uint32(block.timestamp);
    }

    function assertBeams(uint256 userId, BeamsReceiver[] memory currReceivers) internal {
        (bytes32 actual,,,,) = Beams._beamsState(userId, assetId);
        bytes32 expected = Beams._hashBeams(currReceivers);
        assertEq(actual, expected, "Invalid beams configuration");
    }

    function assertBalance(uint256 userId, uint128 expected) internal {
        assertBalanceAt(userId, expected, block.timestamp);
    }

    function assertBalanceAt(uint256 userId, uint128 expected, uint256 timestamp) internal {
        uint128 balance =
            Beams._balanceAt(userId, assetId, loadCurrReceivers(userId), uint32(timestamp));
        assertEq(balance, expected, "Invalid beams balance");
    }

    function assertBalanceAtReverts(
        uint256 userId,
        BeamsReceiver[] memory receivers,
        uint256 timestamp,
        bytes memory expectedReason
    ) internal {
        vm.expectRevert(expectedReason);
        this.balanceAtExternal(userId, receivers, timestamp);
    }

    function balanceAtExternal(uint256 userId, BeamsReceiver[] memory receivers, uint256 timestamp)
        external
        view
    {
        Beams._balanceAt(userId, assetId, receivers, uint32(timestamp));
    }

    function assetMaxEnd(uint256 userId, uint256 expected) public {
        (,,,, uint32 maxEnd) = Beams._beamsState(userId, assetId);
        assertEq(maxEnd, expected, "Invalid max end");
    }

    function assertSetBeamsReverts(
        uint256 userId,
        uint128 balanceFrom,
        uint128 balanceTo,
        BeamsReceiver[] memory newReceivers,
        bytes memory expectedReason
    ) internal {
        assertSetBeamsReverts(
            userId, loadCurrReceivers(userId), balanceFrom, balanceTo, newReceivers, expectedReason
        );
    }

    function assertSetBeamsReverts(
        uint256 userId,
        BeamsReceiver[] memory currReceivers,
        uint128 balanceFrom,
        uint128 balanceTo,
        BeamsReceiver[] memory newReceivers,
        bytes memory expectedReason
    ) internal {
        vm.expectRevert(expectedReason);
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);
        this.setBeamsExternal(userId, currReceivers, balanceDelta, newReceivers);
    }

    function setBeamsExternal(
        uint256 userId,
        BeamsReceiver[] memory currReceivers,
        int128 balanceDelta,
        BeamsReceiver[] memory newReceivers
    ) external {
        Beams._setBeams(userId, assetId, currReceivers, balanceDelta, newReceivers, 0, 0);
    }

    function receiveBeams(uint256 userId, uint128 expectedAmt) internal {
        uint128 actualAmt = Beams._receiveBeams(userId, assetId, type(uint32).max);
        assertEq(actualAmt, expectedAmt, "Invalid amount received from beams");
    }

    function receiveBeams(
        uint256 userId,
        uint32 maxCycles,
        uint128 expectedReceivedAmt,
        uint32 expectedReceivedCycles,
        uint128 expectedAmtAfter,
        uint32 expectedCyclesAfter
    ) internal {
        uint128 expectedTotalAmt = expectedReceivedAmt + expectedAmtAfter;
        uint32 expectedTotalCycles = expectedReceivedCycles + expectedCyclesAfter;
        assertReceivableBeamsCycles(userId, expectedTotalCycles);
        assertReceiveBeamsResult(userId, type(uint32).max, expectedTotalAmt, 0);
        assertReceiveBeamsResult(userId, maxCycles, expectedReceivedAmt, expectedCyclesAfter);

        uint128 receivedAmt = Beams._receiveBeams(userId, assetId, maxCycles);

        assertEq(receivedAmt, expectedReceivedAmt, "Invalid amount received from beams");
        assertReceivableBeamsCycles(userId, expectedCyclesAfter);
        assertReceiveBeamsResult(userId, type(uint32).max, expectedAmtAfter, 0);
    }

    function receiveBeams(BeamsReceiver[] memory receivers, uint32 maxEnd, uint32 updateTime)
        internal
    {
        emit log_named_uint("maxEnd:", maxEnd);
        for (uint256 i = 0; i < receivers.length; i++) {
            BeamsReceiver memory r = receivers[i];
            uint32 duration = r.config.duration();
            uint32 start = r.config.start();
            if (start == 0) {
                start = updateTime;
            }
            if (duration == 0 && maxEnd > start) {
                duration = maxEnd - start;
            }
            // beams was in the past, not added
            if (start + duration < updateTime) {
                duration = 0;
            } else if (start < updateTime) {
                duration -= updateTime - start;
            }

            uint256 expectedAmt = (duration * r.config.amtPerSec()) >> 64;
            uint128 actualAmt = Beams._receiveBeams(r.userId, assetId, type(uint32).max);
            // only log if actualAmt doesn't match expectedAmt
            if (expectedAmt != actualAmt) {
                emit log_named_uint("userId:", r.userId);
                emit log_named_uint("start:", r.config.start());
                emit log_named_uint("duration:", r.config.duration());
                emit log_named_uint("amtPerSec:", r.config.amtPerSec());
            }
            assertEq(actualAmt, expectedAmt);
        }
    }

    function assertReceivableBeamsCycles(uint256 userId, uint32 expectedCycles) internal {
        uint32 actualCycles = Beams._receivableBeamsCycles(userId, assetId);
        assertEq(actualCycles, expectedCycles, "Invalid total receivable beams cycles");
    }

    function assertReceiveBeamsResult(uint256 userId, uint128 expectedAmt) internal {
        (uint128 actualAmt,,,,) = Beams._receiveBeamsResult(userId, assetId, type(uint32).max);
        assertEq(actualAmt, expectedAmt, "Invalid receivable amount");
    }

    function assertReceiveBeamsResult(
        uint256 userId,
        uint32 maxCycles,
        uint128 expectedAmt,
        uint32 expectedCycles
    ) internal {
        (uint128 actualAmt, uint32 actualCycles,,,) =
            Beams._receiveBeamsResult(userId, assetId, maxCycles);
        assertEq(actualAmt, expectedAmt, "Invalid receivable amount");
        assertEq(actualCycles, expectedCycles, "Invalid receivable beams cycles");
    }

    function squeezeBeams(
        uint256 userId,
        uint256 senderId,
        BeamsHistory[] memory beamsHistory,
        uint256 expectedAmt
    ) internal {
        squeezeBeams(userId, senderId, 0, beamsHistory, expectedAmt);
    }

    function squeezeBeams(
        uint256 userId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory,
        uint256 expectedAmt
    ) internal {
        (uint128 amtBefore,,,,) =
            Beams._squeezeBeamsResult(userId, assetId, senderId, historyHash, beamsHistory);
        assertEq(amtBefore, expectedAmt, "Invalid squeezable amount before squeezing");

        uint128 amt = Beams._squeezeBeams(userId, assetId, senderId, historyHash, beamsHistory);

        assertEq(amt, expectedAmt, "Invalid squeezed amount");
        (uint128 amtAfter,,,,) =
            Beams._squeezeBeamsResult(userId, assetId, senderId, historyHash, beamsHistory);
        assertEq(amtAfter, 0, "Squeezable amount after squeezing non-zero");
    }

    function assertSqueezeBeamsReverts(
        uint256 userId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory,
        bytes memory expectedReason
    ) internal {
        vm.expectRevert(expectedReason);
        this.squeezeBeamsExternal(userId, senderId, historyHash, beamsHistory);
        vm.expectRevert(expectedReason);
        this.squeezeBeamsResultExternal(userId, senderId, historyHash, beamsHistory);
    }

    function squeezeBeamsExternal(
        uint256 userId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory
    ) external {
        Beams._squeezeBeams(userId, assetId, senderId, historyHash, beamsHistory);
    }

    function squeezeBeamsResultExternal(
        uint256 userId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory
    ) external view {
        Beams._squeezeBeamsResult(userId, assetId, senderId, historyHash, beamsHistory);
    }

    function testBeamsConfigStoresParameters() public {
        BeamsConfig config = BeamsConfigImpl.create(1, 2, 3, 4);
        assertEq(config.beamId(), 1, "Invalid beamId");
        assertEq(config.amtPerSec(), 2, "Invalid amtPerSec");
        assertEq(config.start(), 3, "Invalid start");
        assertEq(config.duration(), 4, "Invalid duration");
    }

    function testBeamsConfigChecksOrdering() public {
        BeamsConfig config = BeamsConfigImpl.create(1, 1, 1, 1);
        assertFalse(config.lt(config), "Configs equal");

        BeamsConfig higherBeamId = BeamsConfigImpl.create(2, 1, 1, 1);
        assertTrue(config.lt(higherBeamId), "BeamId higher");
        assertFalse(higherBeamId.lt(config), "BeamId lower");

        BeamsConfig higherAmtPerSec = BeamsConfigImpl.create(1, 2, 1, 1);
        assertTrue(config.lt(higherAmtPerSec), "AmtPerSec higher");
        assertFalse(higherAmtPerSec.lt(config), "AmtPerSec lower");

        BeamsConfig higherStart = BeamsConfigImpl.create(1, 1, 2, 1);
        assertTrue(config.lt(higherStart), "Start higher");
        assertFalse(higherStart.lt(config), "Start lower");

        BeamsConfig higherDuration = BeamsConfigImpl.create(1, 1, 1, 2);
        assertTrue(config.lt(higherDuration), "Duration higher");
        assertFalse(higherDuration.lt(config), "Duration lower");
    }

    function testAllowsBeampingToASingleReceiver() public {
        setBeams(sender, 0, 100, recv(receiver, 1), 100);
        skip(15);
        // Sender had 15 seconds paying 1 per second
        drainBalance(sender, 85);
        skipToCycleEnd();
        // Receiver 1 had 15 seconds paying 1 per second
        receiveBeams(receiver, 15);
    }

    function testBeamsToTwoReceivers() public {
        setBeams(sender, 0, 100, recv(recv(receiver1, 1), recv(receiver2, 1)), 50);
        skip(14);
        // Sender had 14 seconds paying 2 per second
        drainBalance(sender, 72);
        skipToCycleEnd();
        // Receiver 1 had 14 seconds paying 1 per second
        receiveBeams(receiver1, 14);
        // Receiver 2 had 14 seconds paying 1 per second
        receiveBeams(receiver2, 14);
    }

    function testBeamsFromTwoSendersToASingleReceiver() public {
        setBeams(sender1, 0, 100, recv(receiver, 1), 100);
        skip(2);
        setBeams(sender2, 0, 100, recv(receiver, 2), 50);
        skip(15);
        // Sender1 had 17 seconds paying 1 per second
        drainBalance(sender1, 83);
        // Sender2 had 15 seconds paying 2 per second
        drainBalance(sender2, 70);
        skipToCycleEnd();
        // Receiver had 2 seconds paying 1 per second and 15 seconds paying 3 per second
        receiveBeams(receiver, 47);
    }

    function testBeamsWithBalanceLowerThan1SecondOfBeamping() public {
        setBeams(sender, 0, 1, recv(receiver, 2), 0);
        skipToCycleEnd();
        drainBalance(sender, 1);
        receiveBeams(receiver, 0);
    }

    function testBeamsWithStartAndDuration() public {
        setBeams(sender, 0, 10, recv(receiver, 1, block.timestamp + 5, 10), maxEndMax());
        skip(5);
        assertBalance(sender, 10);
        skip(10);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 10);
    }

    function testBeamsWithStartAndDurationWithInsufficientBalance() public {
        setBeams(sender, 0, 1, recv(receiver, 1, block.timestamp + 1, 2), 2);
        skip(1);
        assertBalance(sender, 1);
        skip(1);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
    }

    function testBeamsWithOnlyDuration() public {
        setBeams(sender, 0, 10, recv(receiver, 1, 0, 10), maxEndMax());
        skip(10);
        skipToCycleEnd();
        receiveBeams(receiver, 10);
    }

    function testBeamsWithOnlyDurationWithInsufficientBalance() public {
        setBeams(sender, 0, 1, recv(receiver, 1, 0, 2), 1);
        assertBalance(sender, 1);
        skip(1);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
    }

    function testBeamsWithOnlyStart() public {
        setBeams(sender, 0, 10, recv(receiver, 1, block.timestamp + 5, 0), 15);
        skip(5);
        assertBalance(sender, 10);
        skip(10);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 10);
    }

    function testBeamsWithoutDurationHaveCommonEndTime() public {
        // Enough for 8 seconds of beamping
        setBeams(
            sender,
            0,
            39,
            recv(
                recv(receiver1, 1, block.timestamp + 5, 0),
                recv(receiver2, 2, 0, 0),
                recv(receiver3, 3, block.timestamp + 3, 0)
            ),
            8
        );
        skip(8);
        assertBalance(sender, 5);
        skipToCycleEnd();
        receiveBeams(receiver1, 3);
        receiveBeams(receiver2, 16);
        receiveBeams(receiver3, 15);
        drainBalance(sender, 5);
    }

    function testTwoBeamsToSingleReceiver() public {
        setBeams(
            sender,
            0,
            28,
            recv(
                recv(receiver, 1, block.timestamp + 5, 10),
                recv(receiver, 2, block.timestamp + 10, 9)
            ),
            maxEndMax()
        );
        skip(19);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 28);
    }

    function testBeamsOfAllSchedulingModes() public {
        setBeams(
            sender,
            0,
            62,
            recv(
                recv(receiver1, 1, 0, 0),
                recv(receiver2, 2, 0, 4),
                recv(receiver3, 3, block.timestamp + 2, 0),
                recv(receiver4, 4, block.timestamp + 3, 5)
            ),
            10
        );
        skip(10);
        skipToCycleEnd();
        receiveBeams(receiver1, 10);
        receiveBeams(receiver2, 8);
        receiveBeams(receiver3, 24);
        receiveBeams(receiver4, 20);
    }

    function testBeamsWithStartInThePast() public {
        skip(5);
        setBeams(sender, 0, 3, recv(receiver, 1, block.timestamp - 5, 0), 3);
        skip(3);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 3);
    }

    function testBeamsWithStartInThePastAndDurationIntoFuture() public {
        skip(5);
        setBeams(sender, 0, 3, recv(receiver, 1, block.timestamp - 5, 8), maxEndMax());
        skip(3);
        assertBalance(sender, 0);
        skipToCycleEnd();
        receiveBeams(receiver, 3);
    }

    function testBeamsWithStartAndDurationInThePast() public {
        skip(5);
        setBeams(sender, 0, 1, recv(receiver, 1, block.timestamp - 5, 3), 0);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testBeamsWithStartAfterFundsRunOut() public {
        setBeams(
            sender, 0, 4, recv(recv(receiver1, 1), recv(receiver2, 2, block.timestamp + 5, 0)), 4
        );
        skip(6);
        skipToCycleEnd();
        receiveBeams(receiver1, 4);
        receiveBeams(receiver2, 0);
    }

    function testBeamsWithStartInTheFutureCycleCanBeMovedToAnEarlierOne() public {
        setBeams(sender, 0, 1, recv(receiver, 1, block.timestamp + _cycleSecs, 0), _cycleSecs + 1);
        setBeams(sender, 1, 1, recv(receiver, 1), 1);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testBeamsWithZeroDurationReceiversNotSortedByStart() public {
        setBeams(
            sender,
            0,
            7,
            recv(
                recv(receiver1, 2, block.timestamp + 2, 0),
                recv(receiver2, 1, block.timestamp + 1, 0)
            ),
            4
        );
        skip(4);
        skipToCycleEnd();
        // Has been receiving 2 per second for 2 seconds
        receiveBeams(receiver1, 4);
        // Has been receiving 1 per second for 3 seconds
        receiveBeams(receiver2, 3);
    }

    function testDoesNotRequireReceiverToBeInitialized() public {
        receiveBeams(receiver, 0);
    }

    function testDoesNotCollectCyclesBeforeFirstBeam() public {
        skip(_cycleSecs / 2);
        // Beamping starts in 2 cycles
        setBeams(
            sender, 0, 1, recv(receiver, 1, block.timestamp + _cycleSecs * 2, 0), _cycleSecs * 2 + 1
        );
        // The first cycle hasn't been beamping
        skipToCycleEnd();
        assertReceivableBeamsCycles(receiver, 0);
        assertReceiveBeamsResult(receiver, 0);
        // The second cycle hasn't been beamping
        skipToCycleEnd();
        assertReceivableBeamsCycles(receiver, 0);
        assertReceiveBeamsResult(receiver, 0);
        // The third cycle has been beamping
        skipToCycleEnd();
        assertReceivableBeamsCycles(receiver, 1);
        receiveBeams(receiver, 1);
    }

    function testFirstCollectableCycleCanBeMovedEarlier() public {
        // Beamping start in the next cycle
        setBeams(sender1, 0, 1, recv(receiver, 1, block.timestamp + _cycleSecs, 0), _cycleSecs + 1);
        // Beamping start in the current cycle
        setBeams(sender2, 0, 2, recv(receiver, 2), 1);
        skipToCycleEnd();
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
    }

    function testAllowsReceivingWhileBeingBeampedTo() public {
        setBeams(sender, 0, _cycleSecs + 10, recv(receiver, 1), _cycleSecs + 10);
        skipToCycleEnd();
        // Receiver had cycleSecs seconds paying 1 per second
        receiveBeams(receiver, _cycleSecs);
        skip(7);
        // Sender had cycleSecs + 7 seconds paying 1 per second
        drainBalance(sender, 3);
        skipToCycleEnd();
        // Receiver had 7 seconds paying 1 per second
        receiveBeams(receiver, 7);
    }

    function testBeamsFundsUntilTheyRunOut() public {
        setBeams(sender, 0, 100, recv(receiver, 9), 11);
        skip(10);
        // Sender had 10 seconds paying 9 per second, beams balance is about to run out
        assertBalance(sender, 10);
        skip(1);
        // Sender had 11 seconds paying 9 per second, beams balance has run out
        assertBalance(sender, 1);
        // Nothing more will be beamped
        skipToCycleEnd();
        drainBalance(sender, 1);
        receiveBeams(receiver, 99);
    }

    function testAllowsBeamsConfigurationWithOverflowingTotalAmtPerSec() public {
        setBeams(sender, 0, 2, recv(recv(receiver, 1), recv(receiver, type(uint128).max)), 0);
        skipToCycleEnd();
        // Sender hasn't sent anything
        drainBalance(sender, 2);
        // Receiver hasn't received anything
        receiveBeams(receiver, 0);
    }

    function testAllowsBeamsConfigurationWithOverflowingAmtPerCycle() public {
        // amtPerSec is valid, but amtPerCycle is over 2 times higher than int128.max.
        // The multiplier is chosen to prevent the amounts from being "clean" binary numbers
        // which could make the overflowing behavior correct by coincidence.
        uint128 amtPerSec = (uint128(type(int128).max) / _cycleSecs / 1000) * 2345;
        uint128 amt = amtPerSec * 4;
        setBeams(sender, 0, amt, recv(receiver, amtPerSec), 4);
        skipToCycleEnd();
        receiveBeams(receiver, amt);
    }

    function testAllowsBeamsConfigurationWithOverflowingAmtPerCycleAcrossCycleBoundaries() public {
        // amtPerSec is valid, but amtPerCycle is over 2 times higher than int128.max.
        // The multiplier is chosen to prevent the amounts from being "clean" binary numbers
        // which could make the overflowing behavior correct by coincidence.
        uint128 amtPerSec = (uint128(type(int128).max) / _cycleSecs / 1000) * 2345;
        // Beamping time in the current and future cycle
        uint128 secs = 2;
        uint128 amt = amtPerSec * secs * 2;
        setBeams(
            sender,
            0,
            amt,
            recv(receiver, amtPerSec, block.timestamp + _cycleSecs - secs, 0),
            _cycleSecs + 2
        );
        skipToCycleEnd();
        assertReceiveBeamsResult(receiver, amt / 2);
        skipToCycleEnd();
        receiveBeams(receiver, amt);
    }

    function testAllowsBeamsConfigurationWithOverflowingAmtDeltas() public {
        // The amounts in the comments are expressed as parts of `type(int128).max`.
        // AmtPerCycle is 0.812.
        // The multiplier is chosen to prevent the amounts from being "clean" binary numbers
        // which could make the overflowing behavior correct by coincidence.
        uint128 amtPerSec = (uint128(type(int128).max) / _cycleSecs / 1000) * 812;
        uint128 amt = amtPerSec * _cycleSecs;
        // Set amtDeltas to +0.812 for the current cycle and -0.812 for the next.
        setBeams(sender1, 0, amt, recv(receiver, amtPerSec), _cycleSecs);
        // Alter amtDeltas by +0.0812 for the current cycle and -0.0812 for the next one
        // As an intermediate step when the beams start is applied at the middle of the cycle,
        // but the end not yet, apply +0.406 for the current cycle and -0.406 for the next one.
        // It makes amtDeltas reach +1.218 for the current cycle and -1.218 for the next one.
        setBeams(sender2, 0, amtPerSec, recv(receiver, amtPerSec, _cycleSecs / 2, 0), 1);
        skipToCycleEnd();
        receiveBeams(receiver, amt + amtPerSec);
    }

    function testAllowsToppingUpWhileBeamping() public {
        BeamsReceiver[] memory receivers = recv(receiver, 10);
        setBeams(sender, 0, 100, recv(receiver, 10), 10);
        skip(6);
        // Sender had 6 seconds paying 10 per second
        setBeams(sender, 40, 60, receivers, 6);
        skip(5);
        // Sender had 5 seconds paying 10 per second
        drainBalance(sender, 10);
        skipToCycleEnd();
        // Receiver had 11 seconds paying 10 per second
        receiveBeams(receiver, 110);
    }

    function testAllowsToppingUpAfterFundsRunOut() public {
        BeamsReceiver[] memory receivers = recv(receiver, 10);
        setBeams(sender, 0, 100, receivers, 10);
        skip(10);
        // Sender had 10 seconds paying 10 per second
        assertBalance(sender, 0);
        skipToCycleEnd();
        // Receiver had 10 seconds paying 10 per second
        assertReceiveBeamsResult(receiver, 100);
        setBeams(sender, 0, 60, receivers, 6);
        skip(5);
        // Sender had 5 seconds paying 10 per second
        drainBalance(sender, 10);
        skipToCycleEnd();
        // Receiver had 15 seconds paying 10 per second
        receiveBeams(receiver, 150);
    }

    function testAllowsBeampingWhichShouldEndAfterMaxTimestamp() public {
        uint128 balance = type(uint32).max + uint128(6);
        setBeams(sender, 0, balance, recv(receiver, 1), maxEndMax());
        skip(10);
        // Sender had 10 seconds paying 1 per second
        drainBalance(sender, balance - 10);
        skipToCycleEnd();
        // Receiver had 10 seconds paying 1 per second
        receiveBeams(receiver, 10);
    }

    function testAllowsBeampingWithDurationEndingAfterMaxTimestamp() public {
        uint32 maxTimestamp = type(uint32).max;
        uint32 currTimestamp = uint32(block.timestamp);
        uint32 maxDuration = maxTimestamp - currTimestamp;
        uint32 duration = maxDuration + 5;
        setBeams(sender, 0, duration, recv(receiver, 1, 0, duration), maxEndMax());
        skipToCycleEnd();
        receiveBeams(receiver, _cycleSecs);
        setBeams(sender, duration - _cycleSecs, 0, recv(), 0);
    }

    function testAllowsChangingReceiversWhileBeamping() public {
        setBeams(sender, 0, 100, recv(recv(receiver1, 6), recv(receiver2, 6)), 8);
        skip(3);
        setBeams(sender, 64, 64, recv(recv(receiver1, 4), recv(receiver2, 8)), 5);
        skip(4);
        // Sender had 7 seconds paying 12 per second
        drainBalance(sender, 16);
        skipToCycleEnd();
        // Receiver1 had 3 seconds paying 6 per second and 4 seconds paying 4 per second
        receiveBeams(receiver1, 34);
        // Receiver2 had 3 seconds paying 6 per second and 4 seconds paying 8 per second
        receiveBeams(receiver2, 50);
    }

    function testAllowsRemovingReceiversWhileBeamping() public {
        setBeams(sender, 0, 100, recv(recv(receiver1, 5), recv(receiver2, 5)), 10);
        skip(3);
        setBeams(sender, 70, 70, recv(receiver2, 10), 7);
        skip(4);
        setBeams(sender, 30, 30, recv(), 0);
        skip(10);
        // Sender had 7 seconds paying 10 per second
        drainBalance(sender, 30);
        skipToCycleEnd();
        // Receiver1 had 3 seconds paying 5 per second
        receiveBeams(receiver1, 15);
        // Receiver2 had 3 seconds paying 5 per second and 4 seconds paying 10 per second
        receiveBeams(receiver2, 55);
    }

    function testBeampingFractions() public {
        uint256 onePerCycle = Beams._AMT_PER_SEC_MULTIPLIER / _cycleSecs + 1;
        setBeams(sender, 0, 2, recv(receiver, 0, onePerCycle), _cycleSecs * 3 - 1);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testBeampingFractionsWithFundsEnoughForHalfCycle() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        uint256 onePerCycle = Beams._AMT_PER_SEC_MULTIPLIER / _cycleSecs + 1;
        // Full units are beamped on cycle timestamps 4 and 9
        setBeams(sender, 0, 1, recv(receiver, 0, onePerCycle * 2), 9);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testBeampingFractionsWithFundsEnoughForOneCycle() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        uint256 onePerCycle = Beams._AMT_PER_SEC_MULTIPLIER / _cycleSecs + 1;
        // Full units are beamped on cycle timestamps 4 and 9
        setBeams(sender, 0, 2, recv(receiver, 0, onePerCycle * 2), 14);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testBeampingFractionsWithFundsEnoughForTwoCycles() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        uint256 onePerCycle = Beams._AMT_PER_SEC_MULTIPLIER / _cycleSecs + 1;
        // Full units are beamped on cycle timestamps 4 and 9
        setBeams(sender, 0, 4, recv(receiver, 0, onePerCycle * 2), 24);
        skipToCycleEnd();
        assertBalance(sender, 2);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testFractionsAreClearedOnCycleBoundary() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        // Rate of 0.25 per second
        // Full units are beamped on cycle timestamps 3 and 7
        setBeams(sender, 0, 3, recv(receiver, 0, Beams._AMT_PER_SEC_MULTIPLIER / 4 + 1), 17);
        skipToCycleEnd();
        assertBalance(sender, 1);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testFractionsAreAppliedOnCycleSecondsWhenTheyAddUpToWholeUnits() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        // Rate of 0.25 per second
        // Full units are beamped on cycle timestamps 3 and 7
        setBeams(sender, 0, 3, recv(receiver, 0, Beams._AMT_PER_SEC_MULTIPLIER / 4 + 1), 17);
        assertBalanceAt(sender, 3, block.timestamp + 3);
        assertBalanceAt(sender, 2, block.timestamp + 4);
        assertBalanceAt(sender, 2, block.timestamp + 7);
        assertBalanceAt(sender, 1, block.timestamp + 8);
        assertBalanceAt(sender, 1, block.timestamp + 13);
        assertBalanceAt(sender, 0, block.timestamp + 14);
    }

    function testFractionsAreAppliedRegardlessOfStartTime() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        skip(3);
        // Rate of 0.4 per second
        // Full units are beamped on cycle timestamps 3, 5 and 8
        setBeams(sender, 0, 1, recv(receiver, 0, Beams._AMT_PER_SEC_MULTIPLIER / 10 * 4 + 1), 4);
        assertBalanceAt(sender, 1, block.timestamp + 1);
        assertBalanceAt(sender, 0, block.timestamp + 2);
    }

    function testBeamsWithFractionsCanBeSeamlesslyToppedUp() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        // Rate of 0.25 per second
        BeamsReceiver[] memory receivers = recv(receiver, 0, Beams._AMT_PER_SEC_MULTIPLIER / 4 + 1);
        // Full units are beamped on cycle timestamps 3 and 7
        setBeams(sender, 0, 2, receivers, 13);
        // Top up 2
        setBeams(sender, 2, 4, receivers, 23);
        skipToCycleEnd();
        assertBalance(sender, 2);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testFractionsDoNotCumulateOnSender() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        // Rate of 0.25 and 0.33 per second
        setBeams(
            sender,
            0,
            5,
            recv(
                recv(receiver1, 0, Beams._AMT_PER_SEC_MULTIPLIER / 4 + 1),
                recv(receiver2, 0, (Beams._AMT_PER_SEC_MULTIPLIER / 100 + 1) * 33)
            ),
            13
        );
        // Full units are beamped by 0.25 on cycle timestamps 3 and 7, 0.33 on 3, 6 and 9
        assertBalance(sender, 5);
        assertBalanceAt(sender, 5, block.timestamp + 3);
        assertBalanceAt(sender, 3, block.timestamp + 4);
        assertBalanceAt(sender, 3, block.timestamp + 6);
        assertBalanceAt(sender, 2, block.timestamp + 7);
        assertBalanceAt(sender, 1, block.timestamp + 8);
        assertBalanceAt(sender, 1, block.timestamp + 9);
        assertBalanceAt(sender, 0, block.timestamp + 10);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver1, 2);
        receiveBeams(receiver2, 3);
        skipToCycleEnd();
        assertBalance(sender, 0);
        receiveBeams(receiver1, 0);
        receiveBeams(receiver2, 0);
    }

    function testFractionsDoNotCumulateOnReceiver() public {
        assertEq(_cycleSecs, 10, "Unexpected cycle length");
        // Rate of 0.25 per second or 2.5 per cycle
        setBeams(sender1, 0, 3, recv(receiver, 0, Beams._AMT_PER_SEC_MULTIPLIER / 4 + 1), 17);
        // Rate of 0.66 per second or 6.6 per cycle
        setBeams(
            sender2, 0, 7, recv(receiver, 0, (Beams._AMT_PER_SEC_MULTIPLIER / 100 + 1) * 66), 13
        );
        skipToCycleEnd();
        assertBalance(sender1, 1);
        assertBalance(sender2, 1);
        receiveBeams(receiver, 8);
        skipToCycleEnd();
        assertBalance(sender1, 0);
        assertBalance(sender2, 0);
        receiveBeams(receiver, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testLimitsTheTotalReceiversCount() public {
        uint256 countMax = Beams._MAX_DRIPS_RECEIVERS;
        BeamsReceiver[] memory receivers = new BeamsReceiver[](countMax);
        for (uint160 i = 0; i < countMax; i++) {
            receivers[i] = recv(i, 1, 0, 0)[0];
        }
        setBeams(sender, 0, uint128(countMax), receivers, 1);
        receivers = recv(receivers, recv(countMax, 1, 0, 0));
        assertSetBeamsReverts(
            sender, uint128(countMax), uint128(countMax + 1), receivers, "Too many beams receivers"
        );
    }

    function testBenchSetBeams() public {
        initSeed(0);
        uint32 wrongHint1 = uint32(block.timestamp) + 1;
        uint32 wrongHint2 = wrongHint1 + 1;

        uint32 worstEnd = type(uint32).max - 2;
        uint32 worstHint = worstEnd + 1;
        uint32 worstHintPerfect = worstEnd;
        uint32 worstHint1Minute = worstEnd - 1 minutes;
        uint32 worstHint1Hour = worstEnd - 1 hours;

        benchSetBeams("worst 100 no hint        ", 100, worstEnd, 0, 0);
        benchSetBeams("worst 100 perfect hint   ", 100, worstEnd, worstHint, worstHintPerfect);
        benchSetBeams("worst 100 1 minute hint  ", 100, worstEnd, worstHint, worstHint1Minute);
        benchSetBeams("worst 100 1 hour hint    ", 100, worstEnd, worstHint, worstHint1Hour);
        benchSetBeams("worst 100 wrong hint     ", 100, worstEnd, wrongHint1, wrongHint2);
        emit log_string("-----------------------------------------------");

        benchSetBeams("worst 10 no hint         ", 10, worstEnd, 0, 0);
        benchSetBeams("worst 10 perfect hint    ", 10, worstEnd, worstHint, worstHintPerfect);
        benchSetBeams("worst 10 1 minute hint   ", 10, worstEnd, worstHint, worstHint1Minute);
        benchSetBeams("worst 10 1 hour hint     ", 10, worstEnd, worstHint, worstHint1Hour);
        benchSetBeams("worst 10 wrong hint      ", 10, worstEnd, wrongHint1, wrongHint2);
        emit log_string("-----------------------------------------------");

        benchSetBeams("worst 1 no hint          ", 1, worstEnd, 0, 0);
        benchSetBeams("worst 1 perfect hint     ", 1, worstEnd, worstHint, worstHintPerfect);
        benchSetBeams("worst 1 1 minute hint    ", 1, worstEnd, worstHint, worstHint1Minute);
        benchSetBeams("worst 1 1 hour hint      ", 1, worstEnd, worstHint, worstHint1Hour);
        benchSetBeams("worst 1 wrong hint       ", 1, worstEnd, wrongHint1, wrongHint2);
        emit log_string("-----------------------------------------------");

        uint32 monthEnd = uint32(block.timestamp) + 30 days;
        uint32 monthHint = monthEnd + 1;
        uint32 monthHintPerfect = monthEnd;
        uint32 monthHint1Minute = monthEnd - 1 minutes;
        uint32 monthHint1Hour = monthEnd - 1 hours;

        benchSetBeams("1 month 100 no hint      ", 100, monthEnd, 0, 0);
        benchSetBeams("1 month 100 perfect hint ", 100, monthEnd, monthHint, monthHintPerfect);
        benchSetBeams("1 month 100 1 minute hint", 100, monthEnd, monthHint, monthHint1Minute);
        benchSetBeams("1 month 100 1 hour hint  ", 100, monthEnd, monthHint, monthHint1Hour);
        benchSetBeams("1 month 100 wrong hint   ", 100, monthEnd, wrongHint1, wrongHint2);
        emit log_string("-----------------------------------------------");

        benchSetBeams("1 month 10 no hint       ", 10, monthEnd, 0, 0);
        benchSetBeams("1 month 10 perfect hint  ", 10, monthEnd, monthHint, monthHintPerfect);
        benchSetBeams("1 month 10 1 minute hint ", 10, monthEnd, monthHint, monthHint1Minute);
        benchSetBeams("1 month 10 1 hour hint   ", 10, monthEnd, monthHint, monthHint1Hour);
        benchSetBeams("1 month 10 wrong hint    ", 10, monthEnd, wrongHint1, wrongHint2);
        emit log_string("-----------------------------------------------");

        benchSetBeams("1 month 1 no hint        ", 1, monthEnd, 0, 0);
        benchSetBeams("1 month 1 perfect hint   ", 1, monthEnd, monthHint, monthHintPerfect);
        benchSetBeams("1 month 1 1 minute hint  ", 1, monthEnd, monthHint, monthHint1Minute);
        benchSetBeams("1 month 1 1 hour hint    ", 1, monthEnd, monthHint, monthHint1Hour);
        benchSetBeams("1 month 1 wrong hint     ", 1, monthEnd, wrongHint1, wrongHint2);
    }

    function benchSetBeams(
        string memory testName,
        uint256 count,
        uint256 maxEnd,
        uint32 maxEndHint1,
        uint32 maxEndHint2
    ) public {
        uint256 senderId = random(type(uint256).max);
        BeamsReceiver[] memory receivers = new BeamsReceiver[](count);
        for (uint256 i = 0; i < count; i++) {
            receivers[i] = recv(senderId + 1 + i, 1, 0, 0)[0];
        }
        int128 amt = int128(int256((maxEnd - block.timestamp) * count));
        uint256 gas = gasleft();
        Beams._setBeams(senderId, assetId, recv(), amt, receivers, maxEndHint1, maxEndHint2);
        gas -= gasleft();
        emit log_named_uint(string.concat("Gas used for ", testName), gas);
    }

    function testMinAmtPerSec() public {
        new AssertMinAmtPerSec(2, 500_000_000);
        new AssertMinAmtPerSec(3, 333_333_334);
        new AssertMinAmtPerSec(10, 100_000_000);
        new AssertMinAmtPerSec(11, 90_909_091);
        new AssertMinAmtPerSec(999_999_999, 2);
        new AssertMinAmtPerSec(1_000_000_000, 1);
        new AssertMinAmtPerSec(1_000_000_001, 1);
        new AssertMinAmtPerSec(2_000_000_000, 1);
    }

    function testRejectsTooLowAmtPerSecReceivers() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(receiver, 0, _minAmtPerSec - 1), "Beams receiver amtPerSec too low"
        );
    }

    function testAcceptMinAmtPerSecReceivers() public {
        setBeams(sender, 0, 2, recv(receiver, 0, _minAmtPerSec), 3 * _cycleSecs - 1);
        skipToCycleEnd();
        drainBalance(sender, 1);
        receiveBeams(receiver, 1);
    }

    function testBeamsNotSortedByReceiverAreRejected() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(recv(receiver2, 1), recv(receiver1, 1)), ERROR_NOT_SORTED
        );
    }

    function testBeamsNotSortedByBeamIdAreRejected() public {
        assertSetBeamsReverts(
            sender,
            0,
            0,
            recv(recv(receiver, 1, 1, 0, 0, 0), recv(receiver, 0, 1, 0, 0, 0)),
            ERROR_NOT_SORTED
        );
    }

    function testBeamsNotSortedByAmtPerSecAreRejected() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(recv(receiver, 2), recv(receiver, 1)), ERROR_NOT_SORTED
        );
    }

    function testBeamsNotSortedByStartAreRejected() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(recv(receiver, 1, 2, 0), recv(receiver, 1, 1, 0)), ERROR_NOT_SORTED
        );
    }

    function testBeamsNotSortedByDurationAreRejected() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(recv(receiver, 1, 1, 2), recv(receiver, 1, 1, 1)), ERROR_NOT_SORTED
        );
    }

    function testRejectsDuplicateReceivers() public {
        assertSetBeamsReverts(
            sender, 0, 0, recv(recv(receiver, 1), recv(receiver, 1)), ERROR_NOT_SORTED
        );
    }

    function testSetBeamsRevertsIfInvalidCurrReceivers() public {
        setBeams(sender, 0, 1, recv(receiver, 1), 1);
        assertSetBeamsReverts(sender, recv(receiver, 2), 0, 0, recv(), ERROR_INVALID_DRIPS_LIST);
    }

    function testAllowsAnAddressToBeamAndReceiveIndependently() public {
        setBeams(sender, 0, 10, recv(sender, 10), 1);
        skip(1);
        // Sender had 1 second paying 10 per second
        assertBalance(sender, 0);
        skipToCycleEnd();
        // Sender had 1 second paying 10 per second
        receiveBeams(sender, 10);
    }

    function testCapsWithdrawalOfMoreThanBeamsBalance() public {
        BeamsReceiver[] memory receivers = recv(receiver, 1);
        setBeams(sender, 0, 10, receivers, 10);
        skip(4);
        // Sender had 4 second paying 1 per second

        BeamsReceiver[] memory newReceivers = recv();
        int128 realBalanceDelta =
            Beams._setBeams(sender, assetId, receivers, type(int128).min, newReceivers, 0, 0);
        storeCurrReceivers(sender, newReceivers);
        assertBalance(sender, 0);
        assertEq(realBalanceDelta, -6, "Invalid real balance delta");
        assertBalance(sender, 0);
        skipToCycleEnd();
        // Receiver had 4 seconds paying 1 per second
        receiveBeams(receiver, 4);
    }

    function testReceiveNotAllBeamsCycles() public {
        // Enough for 3 cycles
        uint128 amt = _cycleSecs * 3;
        skipToCycleEnd();
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs * 3);
        skipToCycleEnd();
        skipToCycleEnd();
        skipToCycleEnd();
        receiveBeams({
            userId: receiver,
            maxCycles: 2,
            expectedReceivedAmt: _cycleSecs * 2,
            expectedReceivedCycles: 2,
            expectedAmtAfter: _cycleSecs,
            expectedCyclesAfter: 1
        });
        receiveBeams(receiver, _cycleSecs);
    }

    function testSenderCanBeamToThemselves() public {
        uint128 amt = _cycleSecs * 3;
        skipToCycleEnd();
        setBeams(sender, 0, amt, recv(recv(sender, 1), recv(receiver, 2)), _cycleSecs);
        skipToCycleEnd();
        receiveBeams(sender, _cycleSecs);
        receiveBeams(receiver, _cycleSecs * 2);
    }

    function testUpdateDefaultStartBeam() public {
        setBeams(sender, 0, 3 * _cycleSecs, recv(receiver, 1), 3 * _cycleSecs);
        skipToCycleEnd();
        skipToCycleEnd();
        // remove beams after two cycles, no balance change
        setBeams(sender, 10, 10, recv(), 0);

        skipToCycleEnd();
        // only two cycles should be beamped
        receiveBeams(receiver, 2 * _cycleSecs);
    }

    function testBeamsOfDifferentAssetsAreIndependent() public {
        // Covers 1.5 cycles of beamping
        assetId = defaultAssetId;
        setBeams(
            sender,
            0,
            9 * _cycleSecs,
            recv(recv(receiver1, 4), recv(receiver2, 2)),
            _cycleSecs + _cycleSecs / 2
        );

        skipToCycleEnd();
        // Covers 2 cycles of beamping
        assetId = otherAssetId;
        setBeams(sender, 0, 6 * _cycleSecs, recv(receiver1, 3), _cycleSecs * 2);

        skipToCycleEnd();
        // receiver1 had 1.5 cycles of 4 per second
        assetId = defaultAssetId;
        receiveBeams(receiver1, 6 * _cycleSecs);
        // receiver1 had 1.5 cycles of 2 per second
        assetId = defaultAssetId;
        receiveBeams(receiver2, 3 * _cycleSecs);
        // receiver1 had 1 cycle of 3 per second
        assetId = otherAssetId;
        receiveBeams(receiver1, 3 * _cycleSecs);
        // receiver2 received nothing
        assetId = otherAssetId;
        receiveBeams(receiver2, 0);

        skipToCycleEnd();
        // receiver1 received nothing
        assetId = defaultAssetId;
        receiveBeams(receiver1, 0);
        // receiver2 received nothing
        assetId = defaultAssetId;
        receiveBeams(receiver2, 0);
        // receiver1 had 1 cycle of 3 per second
        assetId = otherAssetId;
        receiveBeams(receiver1, 3 * _cycleSecs);
        // receiver2 received nothing
        assetId = otherAssetId;
        receiveBeams(receiver2, 0);
    }

    function testBalanceAtReturnsCurrentBalance() public {
        setBeams(sender, 0, 10, recv(receiver, 1), 10);
        skip(2);
        assertBalanceAt(sender, 8, block.timestamp);
    }

    function testBalanceAtReturnsFutureBalance() public {
        setBeams(sender, 0, 10, recv(receiver, 1), 10);
        skip(2);
        assertBalanceAt(sender, 6, block.timestamp + 2);
    }

    function testBalanceAtReturnsPastBalanceAfterSetDelta() public {
        setBeams(sender, 0, 10, recv(receiver, 1), 10);
        skip(2);
        assertBalanceAt(sender, 10, block.timestamp - 2);
    }

    function testBalanceAtRevertsForTimestampBeforeSetDelta() public {
        BeamsReceiver[] memory receivers = recv(receiver, 1);
        setBeams(sender, 0, 10, receivers, 10);
        skip(2);
        assertBalanceAtReverts(sender, receivers, block.timestamp - 3, ERROR_TIMESTAMP_EARLY);
    }

    function testBalanceAtRevertsForInvalidBeamsList() public {
        BeamsReceiver[] memory receivers = recv(receiver, 1);
        setBeams(sender, 0, 10, receivers, 10);
        skip(2);
        receivers = recv(receiver, 2);
        assertBalanceAtReverts(sender, receivers, block.timestamp, ERROR_INVALID_DRIPS_LIST);
    }

    function testFuzzBeamsReceiver(bytes32 seed) public {
        initSeed(seed);
        uint8 amountReceivers = 10;
        uint160 maxAmtPerSec = _minAmtPerSec + 50;
        uint32 maxDuration = 100;
        uint32 maxStart = 100;

        uint128 maxCosts =
            amountReceivers * uint128(maxAmtPerSec / _AMT_PER_SEC_MULTIPLIER) * maxDuration;
        emit log_named_uint("topUp", maxCosts);
        uint128 maxAllBeamsFinished = maxStart + maxDuration;

        BeamsReceiver[] memory receivers =
            genRandomRecv(amountReceivers, maxAmtPerSec, maxStart, maxDuration);
        emit log_named_uint("setBeams.updateTime", block.timestamp);
        Beams._setBeams(sender, assetId, recv(), int128(maxCosts), receivers, 0, 0);

        (,, uint32 updateTime,, uint32 maxEnd) = Beams._beamsState(sender, assetId);

        if (maxEnd > maxAllBeamsFinished && maxEnd != type(uint32).max) {
            maxAllBeamsFinished = maxEnd;
        }

        skip(maxAllBeamsFinished);
        skipToCycleEnd();
        emit log_named_uint("receiveBeams.time", block.timestamp);
        receiveBeams(receivers, maxEnd, updateTime);
    }

    function sanitizeReceivers(
        BeamsReceiver[_MAX_DRIPS_RECEIVERS] memory receiversRaw,
        uint256 receiversLengthRaw
    ) internal view returns (BeamsReceiver[] memory receivers) {
        receivers = new BeamsReceiver[](bound(receiversLengthRaw, 0, receiversRaw.length));
        for (uint256 i = 0; i < receivers.length; i++) {
            receivers[i] = receiversRaw[i];
        }
        for (uint32 i = 0; i < receivers.length; i++) {
            for (uint256 j = i + 1; j < receivers.length; j++) {
                if (receivers[j].userId < receivers[i].userId) {
                    (receivers[j], receivers[i]) = (receivers[i], receivers[j]);
                }
            }
            BeamsConfig cfg = receivers[i].config;
            uint160 amtPerSec = cfg.amtPerSec();
            if (amtPerSec < _minAmtPerSec) amtPerSec = _minAmtPerSec;
            receivers[i].config = BeamsConfigImpl.create(i, amtPerSec, cfg.start(), cfg.duration());
        }
    }

    struct Sender {
        uint256 userId;
        uint128 balance;
        BeamsReceiver[] receivers;
    }

    function sanitizeSenders(
        uint256 receiverId,
        uint128 balance,
        BeamsReceiver[100] memory sendersRaw,
        uint256 sendersLenRaw
    ) internal view returns (Sender[] memory senders) {
        uint256 sendersLen = bound(sendersLenRaw, 1, sendersRaw.length);
        senders = new Sender[](sendersLen);
        uint256 totalBalanceWeight = 0;
        for (uint32 i = 0; i < sendersLen; i++) {
            BeamsConfig cfg = sendersRaw[i].config;
            senders[i].userId = sendersRaw[i].userId;
            senders[i].balance = cfg.beamId();
            totalBalanceWeight += cfg.beamId();
            senders[i].receivers = new BeamsReceiver[](1);
            senders[i].receivers[0].userId = receiverId;
            uint160 amtPerSec = cfg.amtPerSec();
            if (amtPerSec < _minAmtPerSec) amtPerSec = _minAmtPerSec;
            senders[i].receivers[0].config =
                BeamsConfigImpl.create(i, amtPerSec, cfg.start(), cfg.duration());
        }
        uint256 uniqueSenders = 0;
        uint256 usedBalance = 0;
        uint256 usedBalanceWeight = 0;
        if (totalBalanceWeight == 0) {
            totalBalanceWeight = 1;
            usedBalanceWeight = 1;
        }
        for (uint256 i = 0; i < sendersLen; i++) {
            usedBalanceWeight += senders[i].balance;
            uint256 newUsedBalance = usedBalanceWeight * balance / totalBalanceWeight;
            senders[i].balance = uint128(newUsedBalance - usedBalance);
            usedBalance = newUsedBalance;
            senders[uniqueSenders++] = senders[i];
            for (uint256 j = 0; j + 1 < uniqueSenders; j++) {
                if (senders[i].userId == senders[j].userId) {
                    senders[j].balance += senders[i].balance;
                    senders[j].receivers = recv(senders[j].receivers, senders[i].receivers);
                    uniqueSenders--;
                    break;
                }
            }
        }
        Sender[] memory sendersLong = senders;
        senders = new Sender[](uniqueSenders);
        for (uint256 i = 0; i < uniqueSenders; i++) {
            senders[i] = sendersLong[i];
        }
    }

    function sanitizeBeamTime(uint256 beamTimeRaw, uint256 maxCycles)
        internal
        view
        returns (uint256 beamTime)
    {
        return bound(beamTimeRaw, 0, _cycleSecs * maxCycles);
    }

    function sanitizeBeamBalance(uint256 balanceRaw) internal view returns (uint128 balance) {
        return uint128(bound(balanceRaw, 0, _MAX_TOTAL_DRIPS_BALANCE));
    }

    function testFundsBeampedToReceiversAddUp(
        uint256 senderId,
        uint256 asset,
        uint256 balanceRaw,
        BeamsReceiver[_MAX_DRIPS_RECEIVERS] memory receiversRaw,
        uint256 receiversLengthRaw,
        uint256 beamTimeRaw
    ) public {
        uint128 balanceBefore = sanitizeBeamBalance(balanceRaw);
        BeamsReceiver[] memory receivers = sanitizeReceivers(receiversRaw, receiversLengthRaw);
        Beams._setBeams(senderId, asset, recv(), int128(balanceBefore), receivers, 0, 0);

        skip(sanitizeBeamTime(beamTimeRaw, 100));
        int128 realBalanceDelta =
            Beams._setBeams(senderId, asset, receivers, type(int128).min, receivers, 0, 0);

        skipToCycleEnd();
        uint256 balanceAfter = uint128(-realBalanceDelta);
        for (uint256 i = 0; i < receivers.length; i++) {
            balanceAfter += Beams._receiveBeams(receivers[i].userId, asset, type(uint32).max);
        }
        assertEq(balanceAfter, balanceBefore, "Beamped funds don't add up");
    }

    function testFundsBeampedToReceiversAddUpAfterBeamsUpdate(
        uint256 senderId,
        uint256 asset,
        uint256 balanceRaw,
        BeamsReceiver[_MAX_DRIPS_RECEIVERS] memory receiversRaw1,
        uint256 receiversLengthRaw1,
        uint256 beamTimeRaw1,
        BeamsReceiver[_MAX_DRIPS_RECEIVERS] memory receiversRaw2,
        uint256 receiversLengthRaw2,
        uint256 beamTimeRaw2
    ) public {
        uint128 balanceBefore = sanitizeBeamBalance(balanceRaw);
        BeamsReceiver[] memory receivers1 = sanitizeReceivers(receiversRaw1, receiversLengthRaw1);
        Beams._setBeams(senderId, asset, recv(), int128(balanceBefore), receivers1, 0, 0);

        skip(sanitizeBeamTime(beamTimeRaw1, 50));
        BeamsReceiver[] memory receivers2 = sanitizeReceivers(receiversRaw2, receiversLengthRaw2);
        int128 realBalanceDelta = Beams._setBeams(senderId, asset, receivers1, 0, receivers2, 0, 0);
        assertEq(realBalanceDelta, 0, "Zero balance delta changed balance");

        skip(sanitizeBeamTime(beamTimeRaw2, 50));
        realBalanceDelta =
            Beams._setBeams(senderId, asset, receivers2, type(int128).min, receivers2, 0, 0);

        skipToCycleEnd();
        uint256 balanceAfter = uint128(-realBalanceDelta);
        for (uint256 i = 0; i < receivers1.length; i++) {
            balanceAfter += Beams._receiveBeams(receivers1[i].userId, asset, type(uint32).max);
        }
        for (uint256 i = 0; i < receivers2.length; i++) {
            balanceAfter += Beams._receiveBeams(receivers2[i].userId, asset, type(uint32).max);
        }
        assertEq(balanceAfter, balanceBefore, "Beamped funds don't add up");
    }

    function testFundsBeampedFromSendersAddUp(
        uint256 receiverId,
        uint256 asset,
        uint256 balanceRaw,
        BeamsReceiver[100] memory sendersRaw,
        uint256 sendersLenRaw,
        uint256 beamTimeRaw
    ) public {
        uint128 balanceBefore = sanitizeBeamBalance(balanceRaw);
        Sender[] memory senders =
            sanitizeSenders(receiverId, balanceBefore, sendersRaw, sendersLenRaw);
        for (uint256 i = 0; i < senders.length; i++) {
            Sender memory snd = senders[i];
            Beams._setBeams(snd.userId, asset, recv(), int128(snd.balance), snd.receivers, 0, 0);
        }

        skip(sanitizeBeamTime(beamTimeRaw, 1000));
        uint128 balanceAfter = 0;
        for (uint256 i = 0; i < senders.length; i++) {
            Sender memory snd = senders[i];
            int128 realBalanceDelta = Beams._setBeams(
                snd.userId, asset, snd.receivers, type(int128).min, snd.receivers, 0, 0
            );
            balanceAfter += uint128(-realBalanceDelta);
        }

        skipToCycleEnd();
        balanceAfter += Beams._receiveBeams(receiverId, asset, type(uint32).max);
        assertEq(balanceAfter, balanceBefore, "Beamped funds don't add up");
    }

    function testMaxEndHintsDoNotAffectMaxEnd() public {
        skipTo(10);
        setBeamsPermuteHints({
            amt: 10,
            receivers: recv(receiver, 1),
            maxEndHint1: 15,
            maxEndHint2: 25,
            expectedMaxEndFromNow: 10
        });
    }

    function testMaxEndHintsPerfectlyAccurateDoNotAffectMaxEnd() public {
        skipTo(10);
        setBeamsPermuteHints({
            amt: 10,
            receivers: recv(receiver, 1),
            maxEndHint1: 20,
            maxEndHint2: 21,
            expectedMaxEndFromNow: 10
        });
    }

    function testMaxEndHintsInThePastDoNotAffectMaxEnd() public {
        skipTo(10);
        setBeamsPermuteHints({
            amt: 10,
            receivers: recv(receiver, 1),
            maxEndHint1: 5,
            maxEndHint2: 25,
            expectedMaxEndFromNow: 10
        });
    }

    function testMaxEndHintsAtTheEndOfTimeDoNotAffectMaxEnd() public {
        skipTo(10);
        setBeamsPermuteHints({
            amt: 10,
            receivers: recv(receiver, 1),
            maxEndHint1: type(uint32).max,
            maxEndHint2: 25,
            expectedMaxEndFromNow: 10
        });
    }

    function setBeamsPermuteHints(
        uint128 amt,
        BeamsReceiver[] memory receivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        uint256 expectedMaxEndFromNow
    ) internal {
        setBeamsPermuteHintsCase(amt, receivers, 0, 0, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, 0, maxEndHint1, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, 0, maxEndHint2, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint1, 0, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint2, 0, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint1, maxEndHint2, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint2, maxEndHint1, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint1, maxEndHint1, expectedMaxEndFromNow);
        setBeamsPermuteHintsCase(amt, receivers, maxEndHint2, maxEndHint2, expectedMaxEndFromNow);
    }

    function setBeamsPermuteHintsCase(
        uint128 amt,
        BeamsReceiver[] memory receivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        uint256 expectedMaxEndFromNow
    ) internal {
        emit log_named_uint("Setting beams with hint 1", maxEndHint1);
        emit log_named_uint("               and hint 2", maxEndHint2);
        uint256 snapshot = vm.snapshot();
        setBeams(sender, 0, amt, receivers, maxEndHint1, maxEndHint2, expectedMaxEndFromNow);
        vm.revertTo(snapshot);
    }

    function testSqueezeBeams() public {
        uint128 amt = _cycleSecs;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs);
        skip(2);
        squeezeBeams(receiver, sender, hist(sender), 2);
        skipToCycleEnd();
        receiveBeams(receiver, amt - 2);
    }

    function testSqueezeBeamsRevertsWhenInvalidHistory() public {
        uint128 amt = _cycleSecs;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs);
        BeamsHistory[] memory history = hist(sender);
        history[0].maxEnd += 1;
        skip(2);
        assertSqueezeBeamsReverts(receiver, sender, 0, history, ERROR_HISTORY_INVALID);
    }

    function testSqueezeBeamsRevertsWhenHistoryEntryContainsReceiversAndHash() public {
        uint128 amt = _cycleSecs;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs);
        BeamsHistory[] memory history = hist(sender);
        history[0].beamsHash = Beams._hashBeams(history[0].receivers);
        skip(2);
        assertSqueezeBeamsReverts(receiver, sender, 0, history, ERROR_HISTORY_UNCLEAR);
    }

    function testFundsAreNotSqueezeTwice() public {
        uint128 amt = _cycleSecs;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 1);
        skip(2);
        squeezeBeams(receiver, sender, history, 2);
        skipToCycleEnd();
        receiveBeams(receiver, amt - 3);
    }

    function testFundsFromOldHistoryEntriesAreNotSqueezedTwice() public {
        setBeams(sender, 0, 9, recv(receiver, 1), 9);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        setBeams(sender, 8, 8, recv(receiver, 2), 4);
        history = hist(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 3);
        skip(1);
        squeezeBeams(receiver, sender, history, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 4);
    }

    function testFundsFromFinishedCyclesAreNotSqueezed() public {
        uint128 amt = _cycleSecs * 2;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs * 2);
        skipToCycleEnd();
        skip(2);
        squeezeBeams(receiver, sender, hist(sender), 2);
        skipToCycleEnd();
        receiveBeams(receiver, amt - 2);
    }

    function testHistoryFromFinishedCyclesIsNotSqueezed() public {
        setBeams(sender, 0, 2, recv(receiver, 1), 2);
        BeamsHistory[] memory history = hist(sender);
        skipToCycleEnd();
        setBeams(sender, 0, 6, recv(receiver, 3), 2);
        history = hist(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 3);
        skipToCycleEnd();
        receiveBeams(receiver, 5);
    }

    function testFundsFromBeforeBeampingStartedAreNotSqueezed() public {
        skip(1);
        setBeams(sender, 0, 10, recv(receiver, 1, block.timestamp - 1, 0), 10);
        squeezeBeams(receiver, sender, hist(sender), 0);
        skip(2);
        drainBalance(sender, 8);
        skipToCycleEnd();
        receiveBeams(receiver, 2);
    }

    function testFundsFromAfterBeamsEndAreNotSqueezed() public {
        setBeams(sender, 0, 10, recv(receiver, 1, 0, 2), maxEndMax());
        skip(3);
        squeezeBeams(receiver, sender, hist(sender), 2);
        drainBalance(sender, 8);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testFundsFromAfterBeamsRunOutAreNotSqueezed() public {
        uint128 amt = 2;
        setBeams(sender, 0, amt, recv(receiver, 1), 2);
        skip(3);
        squeezeBeams(receiver, sender, hist(sender), 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testOnFirstSecondOfCycleNoFundsCanBeSqueezed() public {
        uint128 amt = _cycleSecs * 2;
        setBeams(sender, 0, amt, recv(receiver, 1), _cycleSecs * 2);
        skipToCycleEnd();
        squeezeBeams(receiver, sender, hist(sender), 0);
        skipToCycleEnd();
        receiveBeams(receiver, amt);
    }

    function testBeamsWithStartAndDurationCanBeSqueezed() public {
        setBeams(sender, 0, 10, recv(receiver, 1, block.timestamp + 2, 2), maxEndMax());
        skip(5);
        squeezeBeams(receiver, sender, hist(sender), 2);
        skipToCycleEnd();
        receiveBeams(receiver, 0);
    }

    function testEmptyHistoryCanBeSqueezed() public {
        skip(1);
        squeezeBeams(receiver, sender, hist(), 0);
    }

    function testHistoryWithoutTheSqueezingReceiverCanBeSqueezed() public {
        setBeams(sender, 0, 1, recv(receiver1, 1), 1);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        squeezeBeams(receiver2, sender, history, 0);
        skipToCycleEnd();
        receiveBeams(receiver1, 1);
    }

    function testSendersCanBeSqueezedIndependently() public {
        setBeams(sender1, 0, 4, recv(receiver, 2), 2);
        BeamsHistory[] memory history1 = hist(sender1);
        setBeams(sender2, 0, 6, recv(receiver, 3), 2);
        BeamsHistory[] memory history2 = hist(sender2);
        skip(1);
        squeezeBeams(receiver, sender1, history1, 2);
        skip(1);
        squeezeBeams(receiver, sender2, history2, 6);
        skipToCycleEnd();
        receiveBeams(receiver, 2);
    }

    function testMultipleHistoryEntriesCanBeSqueezed() public {
        setBeams(sender, 0, 5, recv(receiver, 1), 5);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        setBeams(sender, 4, 4, recv(receiver, 2), 2);
        history = hist(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 3);
        skipToCycleEnd();
        receiveBeams(receiver, 2);
    }

    function testMiddleHistoryEntryCanBeSkippedWhenSqueezing() public {
        BeamsHistory[] memory history = hist();
        setBeams(sender, 0, 1, recv(receiver, 1), 1);
        history = hist(history, sender);
        skip(1);
        setBeams(sender, 0, 2, recv(receiver, 2), 1);
        history = histSkip(history, sender);
        skip(1);
        setBeams(sender, 0, 4, recv(receiver, 4), 1);
        history = hist(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 5);
        skipToCycleEnd();
        receiveBeams(receiver, 2);
    }

    function testFirstAndLastHistoryEntriesCanBeSkippedWhenSqueezing() public {
        BeamsHistory[] memory history = hist();
        setBeams(sender, 0, 1, recv(receiver, 1), 1);
        history = histSkip(history, sender);
        skip(1);
        setBeams(sender, 0, 2, recv(receiver, 2), 1);
        history = hist(history, sender);
        skip(1);
        setBeams(sender, 0, 4, recv(receiver, 4), 1);
        history = histSkip(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 5);
    }

    function testPartOfTheWholeHistoryCanBeSqueezed() public {
        setBeams(sender, 0, 1, recv(receiver, 1), 1);
        (, bytes32 historyHash,,,) = Beams._beamsState(sender, assetId);
        skip(1);
        setBeams(sender, 0, 2, recv(receiver, 2), 1);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        squeezeBeams(receiver, sender, historyHash, history, 2);
        skipToCycleEnd();
        receiveBeams(receiver, 1);
    }

    function testBeamsWithCopiesOfTheReceiverCanBeSqueezed() public {
        setBeams(sender, 0, 6, recv(recv(receiver, 1), recv(receiver, 2)), 2);
        skip(1);
        squeezeBeams(receiver, sender, hist(sender), 3);
        skipToCycleEnd();
        receiveBeams(receiver, 3);
    }

    function testBeamsWithManyReceiversCanBeSqueezed() public {
        setBeams(sender, 0, 14, recv(recv(receiver1, 1), recv(receiver2, 2), recv(receiver3, 4)), 2);
        skip(1);
        squeezeBeams(receiver2, sender, hist(sender), 2);
        skipToCycleEnd();
        receiveBeams(receiver1, 2);
        receiveBeams(receiver2, 2);
        receiveBeams(receiver3, 8);
    }

    function testPartiallySqueezedOldHistoryEntryCanBeSqueezedFully() public {
        setBeams(sender, 0, 8, recv(receiver, 1), 8);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 1);
        skip(1);
        setBeams(sender, 6, 6, recv(receiver, 2), 3);
        history = hist(history, sender);
        skip(1);
        squeezeBeams(receiver, sender, history, 3);
        skipToCycleEnd();
        receiveBeams(receiver, 4);
    }

    function testUnsqueezedHistoryEntriesFromBeforeLastSqueezeCanBeSqueezed() public {
        setBeams(sender, 0, 9, recv(receiver, 1), 9);
        BeamsHistory[] memory history1 = histSkip(sender);
        BeamsHistory[] memory history2 = hist(sender);
        skip(1);
        setBeams(sender, 8, 8, recv(receiver, 2), 4);
        history1 = hist(history1, sender);
        history2 = histSkip(history2, sender);
        skip(1);
        squeezeBeams(receiver, sender, history1, 2);
        squeezeBeams(receiver, sender, history2, 1);
        skipToCycleEnd();
        receiveBeams(receiver, 6);
    }

    function testLastSqueezedForPastCycleIsIgnored() public {
        setBeams(sender, 0, 3, recv(receiver, 1), 3);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        // Set the first element of the next squeezed table
        squeezeBeams(receiver, sender, history, 1);
        setBeams(sender, 2, 2, recv(receiver, 2), 1);
        history = hist(history, sender);
        skip(1);
        // Set the second element of the next squeezed table
        squeezeBeams(receiver, sender, history, 2);
        skipToCycleEnd();
        setBeams(sender, 0, 8, recv(receiver, 3), 2);
        history = hist(history, sender);
        skip(1);
        setBeams(sender, 5, 5, recv(receiver, 5), 1);
        history = hist(history, sender);
        skip(1);
        // The next squeezed table entries are ignored
        squeezeBeams(receiver, sender, history, 8);
    }

    function testLastSqueezedForConfigurationSetInPastCycleIsKeptAfterUpdatingBeams() public {
        setBeams(sender, 0, 2, recv(receiver, 2), 1);
        BeamsHistory[] memory history = hist(sender);
        skip(1);
        // Set the first element of the next squeezed table
        squeezeBeams(receiver, sender, history, 2);
        setBeams(sender, 0, _cycleSecs + 1, recv(receiver, 1), _cycleSecs + 1);
        history = hist(history, sender);
        skip(1);
        // Set the second element of the next squeezed table
        squeezeBeams(receiver, sender, history, 1);
        skipToCycleEnd();
        skip(1);
        // Set the first element of the next squeezed table
        squeezeBeams(receiver, sender, history, 1);
        skip(1);
        setBeams(sender, 0, 3, recv(receiver, 3), 1);
        history = hist(history, sender);
        skip(1);
        // There's 1 second of unsqueezed beamping of 1 per second in the current cycle
        squeezeBeams(receiver, sender, history, 4);
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.19;
struct BeamsReceiver {
    uint256 userId;
    BeamsConfig config;
}
struct BeamsHistory {
    bytes32 beamsHash;
    BeamsReceiver[] receivers;
    uint32 updateTime;
    uint32 maxEnd;
}

type BeamsConfig is uint256;

using BeamsConfigImpl for BeamsConfig global;

library BeamsConfigImpl {
    function create(
        uint32 beamId_,
        uint160 amtPerSec_,
        uint32 start_,
        uint32 duration_
    ) internal pure returns (BeamsConfig) {
        uint256 config = beamId_;

        config = (config << 160) | amtPerSec_;

        config = (config << 32) | start_;

        config = (config << 32) | duration_;
        return BeamsConfig.wrap(config);
    }

    function beamId(BeamsConfig config) internal pure returns (uint32) {
        return uint32(BeamsConfig.unwrap(config) >> 224);
    }

    function amtPerSec(BeamsConfig config) internal pure returns (uint160) {
        return uint160(BeamsConfig.unwrap(config) >> 64);
    }

    function start(BeamsConfig config) internal pure returns (uint32) {
        return uint32(BeamsConfig.unwrap(config) >> 32);
    }

    function duration(BeamsConfig config) internal pure returns (uint32) {
        return uint32(BeamsConfig.unwrap(config));
    }

    function lt(
        BeamsConfig config,
        BeamsConfig otherConfig
    ) internal pure returns (bool isLower) {
        return BeamsConfig.unwrap(config) < BeamsConfig.unwrap(otherConfig);
    }
}

abstract contract Beams {
    uint256 internal constant _MAX_DRIPS_RECEIVERS = 100;
    uint8 internal constant _AMT_PER_SEC_EXTRA_DECIMALS = 9;
    uint160 internal constant _AMT_PER_SEC_MULTIPLIER = 1_000_000_000;
    uint256 internal constant _MAX_TOTAL_DRIPS_BALANCE =
        uint128(type(int128).max);
    uint32 internal immutable _cycleSecs;
    uint160 internal immutable _minAmtPerSec;
    bytes32 private immutable _beamsStorageSlot;

    event BeamsSet(
        uint256 indexed userId,
        uint256 indexed assetId,
        bytes32 indexed receiversHash,
        bytes32 beamsHistoryHash,
        uint128 balance,
        uint32 maxEnd
    );

    event BeamsReceiverSeen(
        bytes32 indexed receiversHash,
        uint256 indexed userId,
        BeamsConfig config
    );

    event ReceivedBeams(
        uint256 indexed userId,
        uint256 indexed assetId,
        uint128 amt,
        uint32 receivableCycles
    );

    event SqueezedBeams(
        uint256 indexed userId,
        uint256 indexed assetId,
        uint256 indexed senderId,
        uint128 amt,
        bytes32[] beamsHistoryHashes
    );

    struct BeamsStorage {
        mapping(uint256 assetId => mapping(uint256 userId => BeamsState)) states;
    }

    struct BeamsState {
        bytes32 beamsHistoryHash;
        mapping(uint256 userId => uint32[2 ** 32]) nextSqueezed;
        bytes32 beamsHash;
        uint32 nextReceivableCycle;
        uint32 updateTime;
        uint32 maxEnd;
        uint128 balance;
        uint32 currCycleConfigs;
        mapping(uint32 cycle => AmtDelta) amtDeltas;
    }

    struct AmtDelta {
        int128 thisCycle;
        int128 nextCycle;
    }

    constructor(uint32 cycleSecs, bytes32 beamsStorageSlot) {
        require(cycleSecs > 1, "Cycle length too low");
        _cycleSecs = cycleSecs;
        _minAmtPerSec = (_AMT_PER_SEC_MULTIPLIER + cycleSecs - 1) / cycleSecs;
        _beamsStorageSlot = beamsStorageSlot;
    }

    function _receiveBeams(
        uint256 userId,
        uint256 assetId,
        uint32 maxCycles
    ) internal returns (uint128 receivedAmt) {
        uint32 receivableCycles;
        uint32 fromCycle;
        uint32 toCycle;
        int128 finalAmtPerCycle;
        (
            receivedAmt,
            receivableCycles,
            fromCycle,
            toCycle,
            finalAmtPerCycle
        ) = _receiveBeamsResult(userId, assetId, maxCycles);
        if (fromCycle != toCycle) {
            BeamsState storage state = _beamsStorage().states[assetId][userId];
            state.nextReceivableCycle = toCycle;
            mapping(uint32 cycle => AmtDelta) storage amtDeltas = state
                .amtDeltas;
            unchecked {
                for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                    delete amtDeltas[cycle];
                }

                if (finalAmtPerCycle != 0) {
                    amtDeltas[toCycle].thisCycle += finalAmtPerCycle;
                }
            }
        }
        emit ReceivedBeams(userId, assetId, receivedAmt, receivableCycles);
    }

    function _receiveBeamsResult(
        uint256 userId,
        uint256 assetId,
        uint32 maxCycles
    )
        internal
        view
        returns (
            uint128 receivedAmt,
            uint32 receivableCycles,
            uint32 fromCycle,
            uint32 toCycle,
            int128 amtPerCycle
        )
    {
        unchecked {
            (fromCycle, toCycle) = _receivableBeamsCyclesRange(userId, assetId);
            if (toCycle - fromCycle > maxCycles) {
                receivableCycles = toCycle - fromCycle - maxCycles;
                toCycle -= receivableCycles;
            }
            mapping(uint32 cycle => AmtDelta)
                storage amtDeltas = _beamsStorage()
                .states[assetId][userId].amtDeltas;
            for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                AmtDelta memory amtDelta = amtDeltas[cycle];
                amtPerCycle += amtDelta.thisCycle;
                receivedAmt += uint128(amtPerCycle);
                amtPerCycle += amtDelta.nextCycle;
            }
        }
    }

    function _receivableBeamsCycles(
        uint256 userId,
        uint256 assetId
    ) internal view returns (uint32 cycles) {
        unchecked {
            (uint32 fromCycle, uint32 toCycle) = _receivableBeamsCyclesRange(
                userId,
                assetId
            );
            return toCycle - fromCycle;
        }
    }

    function _receivableBeamsCyclesRange(
        uint256 userId,
        uint256 assetId
    ) private view returns (uint32 fromCycle, uint32 toCycle) {
        fromCycle = _beamsStorage().states[assetId][userId].nextReceivableCycle;
        toCycle = _cycleOf(_currTimestamp());

        if (fromCycle == 0 || toCycle < fromCycle) {
            toCycle = fromCycle;
        }
    }

    function _squeezeBeams(
        uint256 userId,
        uint256 assetId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory
    ) internal returns (uint128 amt) {
        unchecked {
            uint256 squeezedNum;
            uint256[] memory squeezedRevIdxs;
            bytes32[] memory historyHashes;
            uint256 currCycleConfigs;
            (
                amt,
                squeezedNum,
                squeezedRevIdxs,
                historyHashes,
                currCycleConfigs
            ) = _squeezeBeamsResult(
                userId,
                assetId,
                senderId,
                historyHash,
                beamsHistory
            );
            bytes32[] memory squeezedHistoryHashes = new bytes32[](squeezedNum);
            BeamsState storage state = _beamsStorage().states[assetId][userId];
            uint32[2 ** 32] storage nextSqueezed = state.nextSqueezed[senderId];
            for (uint256 i = 0; i < squeezedNum; i++) {
                uint256 revIdx = squeezedRevIdxs[squeezedNum - i - 1];
                squeezedHistoryHashes[i] = historyHashes[
                    historyHashes.length - revIdx
                ];
                nextSqueezed[currCycleConfigs - revIdx] = _currTimestamp();
            }
            uint32 cycleStart = _currCycleStart();
            _addDeltaRange(
                state,
                cycleStart,
                cycleStart + 1,
                -int160(amt * _AMT_PER_SEC_MULTIPLIER)
            );
            emit SqueezedBeams(
                userId,
                assetId,
                senderId,
                amt,
                squeezedHistoryHashes
            );
        }
    }

    function _squeezeBeamsResult(
        uint256 userId,
        uint256 assetId,
        uint256 senderId,
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory
    )
        internal
        view
        returns (
            uint128 amt,
            uint256 squeezedNum,
            uint256[] memory squeezedRevIdxs,
            bytes32[] memory historyHashes,
            uint256 currCycleConfigs
        )
    {
        {
            BeamsState storage sender = _beamsStorage().states[assetId][
                senderId
            ];
            historyHashes = _verifyBeamsHistory(
                historyHash,
                beamsHistory,
                sender.beamsHistoryHash
            );
            currCycleConfigs = 1;

            if (sender.updateTime >= _currCycleStart())
                currCycleConfigs = sender.currCycleConfigs;
        }
        squeezedRevIdxs = new uint256[](beamsHistory.length);
        uint32[2 ** 32] storage nextSqueezed = _beamsStorage()
        .states[assetId][userId].nextSqueezed[senderId];
        uint32 squeezeEndCap = _currTimestamp();
        unchecked {
            for (
                uint256 i = 1;
                i <= beamsHistory.length && i <= currCycleConfigs;
                i++
            ) {
                BeamsHistory memory beams = beamsHistory[
                    beamsHistory.length - i
                ];
                if (beams.receivers.length != 0) {
                    uint32 squeezeStartCap = nextSqueezed[currCycleConfigs - i];
                    if (squeezeStartCap < _currCycleStart())
                        squeezeStartCap = _currCycleStart();
                    if (squeezeStartCap < beams.updateTime)
                        squeezeStartCap = beams.updateTime;
                    if (squeezeStartCap < squeezeEndCap) {
                        squeezedRevIdxs[squeezedNum++] = i;
                        amt += _squeezedAmt(
                            userId,
                            beams,
                            squeezeStartCap,
                            squeezeEndCap
                        );
                    }
                }
                squeezeEndCap = beams.updateTime;
            }
        }
    }

    function _verifyBeamsHistory(
        bytes32 historyHash,
        BeamsHistory[] memory beamsHistory,
        bytes32 finalHistoryHash
    ) private pure returns (bytes32[] memory historyHashes) {
        historyHashes = new bytes32[](beamsHistory.length);
        for (uint256 i = 0; i < beamsHistory.length; i++) {
            BeamsHistory memory beams = beamsHistory[i];
            bytes32 beamsHash = beams.beamsHash;
            if (beams.receivers.length != 0) {
                require(beamsHash == 0, "Entry with hash and receivers");
                beamsHash = _hashBeams(beams.receivers);
            }
            historyHashes[i] = historyHash;
            historyHash = _hashBeamsHistory(
                historyHash,
                beamsHash,
                beams.updateTime,
                beams.maxEnd
            );
        }

        require(historyHash == finalHistoryHash, "Invalid beams history");
    }

    function _squeezedAmt(
        uint256 userId,
        BeamsHistory memory beamsHistory,
        uint32 squeezeStartCap,
        uint32 squeezeEndCap
    ) private view returns (uint128 squeezedAmt) {
        unchecked {
            BeamsReceiver[] memory receivers = beamsHistory.receivers;

            uint256 idx = 0;
            for (uint256 idxCap = receivers.length; idx < idxCap; ) {
                uint256 idxMid = (idx + idxCap) / 2;
                if (receivers[idxMid].userId < userId) {
                    idx = idxMid + 1;
                } else {
                    idxCap = idxMid;
                }
            }
            uint32 updateTime = beamsHistory.updateTime;
            uint32 maxEnd = beamsHistory.maxEnd;
            uint256 amt = 0;
            for (; idx < receivers.length; idx++) {
                BeamsReceiver memory receiver = receivers[idx];
                if (receiver.userId != userId) break;
                (uint32 start, uint32 end) = _beamsRange(
                    receiver,
                    updateTime,
                    maxEnd,
                    squeezeStartCap,
                    squeezeEndCap
                );
                amt += _beampedAmt(receiver.config.amtPerSec(), start, end);
            }
            return uint128(amt);
        }
    }

    function _beamsState(
        uint256 userId,
        uint256 assetId
    )
        internal
        view
        returns (
            bytes32 beamsHash,
            bytes32 beamsHistoryHash,
            uint32 updateTime,
            uint128 balance,
            uint32 maxEnd
        )
    {
        BeamsState storage state = _beamsStorage().states[assetId][userId];
        return (
            state.beamsHash,
            state.beamsHistoryHash,
            state.updateTime,
            state.balance,
            state.maxEnd
        );
    }

    function _balanceAt(
        uint256 userId,
        uint256 assetId,
        BeamsReceiver[] memory currReceivers,
        uint32 timestamp
    ) internal view returns (uint128 balance) {
        BeamsState storage state = _beamsStorage().states[assetId][userId];
        require(
            timestamp >= state.updateTime,
            "Timestamp before the last update"
        );
        _verifyBeamsReceivers(currReceivers, state);
        return
            _calcBalance(
                state.balance,
                state.updateTime,
                state.maxEnd,
                currReceivers,
                timestamp
            );
    }

    function _calcBalance(
        uint128 lastBalance,
        uint32 lastUpdate,
        uint32 maxEnd,
        BeamsReceiver[] memory receivers,
        uint32 timestamp
    ) private view returns (uint128 balance) {
        unchecked {
            balance = lastBalance;
            for (uint256 i = 0; i < receivers.length; i++) {
                BeamsReceiver memory receiver = receivers[i];
                (uint32 start, uint32 end) = _beamsRange({
                    receiver: receiver,
                    updateTime: lastUpdate,
                    maxEnd: maxEnd,
                    startCap: lastUpdate,
                    endCap: timestamp
                });
                balance -= uint128(
                    _beampedAmt(receiver.config.amtPerSec(), start, end)
                );
            }
        }
    }

    function _setBeams(
        uint256 userId,
        uint256 assetId,
        BeamsReceiver[] memory currReceivers,
        int128 balanceDelta,
        BeamsReceiver[] memory newReceivers,
        uint32 maxEndHint1,
        uint32 maxEndHint2
    ) internal returns (int128 realBalanceDelta) {
        unchecked {
            BeamsState storage state = _beamsStorage().states[assetId][userId];
            _verifyBeamsReceivers(currReceivers, state);
            uint32 lastUpdate = state.updateTime;
            uint128 newBalance;
            uint32 newMaxEnd;
            {
                uint32 currMaxEnd = state.maxEnd;
                int128 currBalance = int128(
                    _calcBalance(
                        state.balance,
                        lastUpdate,
                        currMaxEnd,
                        currReceivers,
                        _currTimestamp()
                    )
                );
                realBalanceDelta = balanceDelta;

                if (realBalanceDelta < -currBalance) {
                    realBalanceDelta = -currBalance;
                }
                newBalance = uint128(currBalance + realBalanceDelta);
                newMaxEnd = _calcMaxEnd(
                    newBalance,
                    newReceivers,
                    maxEndHint1,
                    maxEndHint2
                );
                _updateReceiverStates(
                    _beamsStorage().states[assetId],
                    currReceivers,
                    lastUpdate,
                    currMaxEnd,
                    newReceivers,
                    newMaxEnd
                );
            }
            state.updateTime = _currTimestamp();
            state.maxEnd = newMaxEnd;
            state.balance = newBalance;
            bytes32 beamsHistory = state.beamsHistoryHash;

            if (
                beamsHistory != 0 &&
                _cycleOf(lastUpdate) != _cycleOf(_currTimestamp())
            ) {
                state.currCycleConfigs = 2;
            } else {
                state.currCycleConfigs++;
            }
            bytes32 newBeamsHash = _hashBeams(newReceivers);
            state.beamsHistoryHash = _hashBeamsHistory(
                beamsHistory,
                newBeamsHash,
                _currTimestamp(),
                newMaxEnd
            );
            emit BeamsSet(
                userId,
                assetId,
                newBeamsHash,
                beamsHistory,
                newBalance,
                newMaxEnd
            );

            if (newBeamsHash != state.beamsHash) {
                state.beamsHash = newBeamsHash;
                for (uint256 i = 0; i < newReceivers.length; i++) {
                    BeamsReceiver memory receiver = newReceivers[i];
                    emit BeamsReceiverSeen(
                        newBeamsHash,
                        receiver.userId,
                        receiver.config
                    );
                }
            }
        }
    }

    function _verifyBeamsReceivers(
        BeamsReceiver[] memory currReceivers,
        BeamsState storage state
    ) private view {
        require(
            _hashBeams(currReceivers) == state.beamsHash,
            "Invalid current beams list"
        );
    }

    function _calcMaxEnd(
        uint128 balance,
        BeamsReceiver[] memory receivers,
        uint32 hint1,
        uint32 hint2
    ) private view returns (uint32 maxEnd) {
        (uint256[] memory configs, uint256 configsLen) = _buildConfigs(
            receivers
        );

        uint256 enoughEnd = _currTimestamp();

        if (configsLen == 0 || balance == 0) {
            return uint32(enoughEnd);
        }

        uint256 notEnoughEnd = type(uint32).max;
        if (_isBalanceEnough(balance, configs, configsLen, notEnoughEnd)) {
            return uint32(notEnoughEnd);
        }

        if (hint1 > enoughEnd && hint1 < notEnoughEnd) {
            if (_isBalanceEnough(balance, configs, configsLen, hint1)) {
                enoughEnd = hint1;
            } else {
                notEnoughEnd = hint1;
            }
        }

        if (hint2 > enoughEnd && hint2 < notEnoughEnd) {
            if (_isBalanceEnough(balance, configs, configsLen, hint2)) {
                enoughEnd = hint2;
            } else {
                notEnoughEnd = hint2;
            }
        }

        while (true) {
            uint256 end;
            unchecked {
                end = (enoughEnd + notEnoughEnd) / 2;
            }
            if (end == enoughEnd) {
                return uint32(end);
            }
            if (_isBalanceEnough(balance, configs, configsLen, end)) {
                enoughEnd = end;
            } else {
                notEnoughEnd = end;
            }
        }
    }

    function _isBalanceEnough(
        uint256 balance,
        uint256[] memory configs,
        uint256 configsLen,
        uint256 maxEnd
    ) private view returns (bool isEnough) {
        unchecked {
            uint256 spent = 0;
            for (uint256 i = 0; i < configsLen; i++) {
                (uint256 amtPerSec, uint256 start, uint256 end) = _getConfig(
                    configs,
                    i
                );

                if (maxEnd <= start) {
                    continue;
                }

                if (end > maxEnd) {
                    end = maxEnd;
                }
                spent += _beampedAmt(amtPerSec, start, end);
                if (spent > balance) {
                    return false;
                }
            }
            return true;
        }
    }

    function _buildConfigs(
        BeamsReceiver[] memory receivers
    ) private view returns (uint256[] memory configs, uint256 configsLen) {
        unchecked {
            require(
                receivers.length <= _MAX_DRIPS_RECEIVERS,
                "Too many beams receivers"
            );
            configs = new uint256[](receivers.length);
            for (uint256 i = 0; i < receivers.length; i++) {
                BeamsReceiver memory receiver = receivers[i];
                if (i > 0) {
                    require(
                        _isOrdered(receivers[i - 1], receiver),
                        "Beams receivers not sorted"
                    );
                }
                configsLen = _addConfig(configs, configsLen, receiver);
            }
        }
    }

    function _addConfig(
        uint256[] memory configs,
        uint256 configsLen,
        BeamsReceiver memory receiver
    ) private view returns (uint256 newConfigsLen) {
        uint160 amtPerSec = receiver.config.amtPerSec();
        require(amtPerSec >= _minAmtPerSec, "Beams receiver amtPerSec too low");
        (uint32 start, uint32 end) = _beamsRangeInFuture(
            receiver,
            _currTimestamp(),
            type(uint32).max
        );

        if (start == end) {
            return configsLen;
        }

        uint256 config = amtPerSec;

        config = (config << 32) | start;

        config = (config << 32) | end;
        configs[configsLen] = config;
        unchecked {
            return configsLen + 1;
        }
    }

    function _getConfig(
        uint256[] memory configs,
        uint256 idx
    ) private pure returns (uint256 amtPerSec, uint256 start, uint256 end) {
        uint256 config;
        assembly ("memory-safe") {
            config := mload(add(32, add(configs, shl(5, idx))))
        }

        amtPerSec = config >> 64;

        start = uint32(config >> 32);

        end = uint32(config);
    }

    function _hashBeams(
        BeamsReceiver[] memory receivers
    ) internal pure returns (bytes32 beamsHash) {
        if (receivers.length == 0) {
            return bytes32(0);
        }
        return keccak256(abi.encode(receivers));
    }

    function _hashBeamsHistory(
        bytes32 oldBeamsHistoryHash,
        bytes32 beamsHash,
        uint32 updateTime,
        uint32 maxEnd
    ) internal pure returns (bytes32 beamsHistoryHash) {
        return
            keccak256(
                abi.encode(oldBeamsHistoryHash, beamsHash, updateTime, maxEnd)
            );
    }

    function _updateReceiverStates(
        mapping(uint256 userId => BeamsState) storage states,
        BeamsReceiver[] memory currReceivers,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        BeamsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    ) private {
        uint256 currIdx = 0;
        uint256 newIdx = 0;
        while (true) {
            bool pickCurr = currIdx < currReceivers.length;

            BeamsReceiver memory currRecv;
            if (pickCurr) {
                currRecv = currReceivers[currIdx];
            }

            bool pickNew = newIdx < newReceivers.length;

            BeamsReceiver memory newRecv;
            if (pickNew) {
                newRecv = newReceivers[newIdx];
            }

            if (pickCurr && pickNew) {
                if (
                    currRecv.userId != newRecv.userId ||
                    currRecv.config.amtPerSec() != newRecv.config.amtPerSec()
                ) {
                    pickCurr = _isOrdered(currRecv, newRecv);
                    pickNew = !pickCurr;
                }
            }

            if (pickCurr && pickNew) {
                BeamsState storage state = states[currRecv.userId];
                (uint32 currStart, uint32 currEnd) = _beamsRangeInFuture(
                    currRecv,
                    lastUpdate,
                    currMaxEnd
                );
                (uint32 newStart, uint32 newEnd) = _beamsRangeInFuture(
                    newRecv,
                    _currTimestamp(),
                    newMaxEnd
                );
                int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));

                _addDeltaRange(state, currStart, newStart, -amtPerSec);
                _addDeltaRange(state, currEnd, newEnd, amtPerSec);

                uint32 currStartCycle = _cycleOf(currStart);
                uint32 newStartCycle = _cycleOf(newStart);

                if (
                    currStartCycle > newStartCycle &&
                    state.nextReceivableCycle > newStartCycle
                ) {
                    state.nextReceivableCycle = newStartCycle;
                }
            } else if (pickCurr) {
                BeamsState storage state = states[currRecv.userId];
                (uint32 start, uint32 end) = _beamsRangeInFuture(
                    currRecv,
                    lastUpdate,
                    currMaxEnd
                );

                int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
                _addDeltaRange(state, start, end, -amtPerSec);
            } else if (pickNew) {
                BeamsState storage state = states[newRecv.userId];

                (uint32 start, uint32 end) = _beamsRangeInFuture(
                    newRecv,
                    _currTimestamp(),
                    newMaxEnd
                );
                int256 amtPerSec = int256(uint256(newRecv.config.amtPerSec()));
                _addDeltaRange(state, start, end, amtPerSec);

                uint32 startCycle = _cycleOf(start);

                uint32 nextReceivableCycle = state.nextReceivableCycle;
                if (
                    nextReceivableCycle == 0 || nextReceivableCycle > startCycle
                ) {
                    state.nextReceivableCycle = startCycle;
                }
            } else {
                break;
            }

            unchecked {
                if (pickCurr) {
                    currIdx++;
                }
                if (pickNew) {
                    newIdx++;
                }
            }
        }
    }

    function _beamsRangeInFuture(
        BeamsReceiver memory receiver,
        uint32 updateTime,
        uint32 maxEnd
    ) private view returns (uint32 start, uint32 end) {
        return
            _beamsRange(
                receiver,
                updateTime,
                maxEnd,
                _currTimestamp(),
                type(uint32).max
            );
    }

    function _beamsRange(
        BeamsReceiver memory receiver,
        uint32 updateTime,
        uint32 maxEnd,
        uint32 startCap,
        uint32 endCap
    ) private pure returns (uint32 start, uint32 end_) {
        start = receiver.config.start();

        if (start == 0) {
            start = updateTime;
        }
        uint40 end;
        unchecked {
            end = uint40(start) + receiver.config.duration();
        }

        if (end == start || end > maxEnd) {
            end = maxEnd;
        }
        if (start < startCap) {
            start = startCap;
        }
        if (end > endCap) {
            end = endCap;
        }
        if (end < start) {
            end = start;
        }

        return (start, uint32(end));
    }

    function _addDeltaRange(
        BeamsState storage state,
        uint32 start,
        uint32 end,
        int256 amtPerSec
    ) private {
        if (start == end) {
            return;
        }
        mapping(uint32 cycle => AmtDelta) storage amtDeltas = state.amtDeltas;
        _addDelta(amtDeltas, start, amtPerSec);
        _addDelta(amtDeltas, end, -amtPerSec);
    }

    function _addDelta(
        mapping(uint32 cycle => AmtDelta) storage amtDeltas,
        uint256 timestamp,
        int256 amtPerSec
    ) private {
        unchecked {
            int256 amtPerSecMultiplier = int160(_AMT_PER_SEC_MULTIPLIER);
            int256 fullCycle = (int256(uint256(_cycleSecs)) * amtPerSec) /
                amtPerSecMultiplier;

            int256 nextCycle = (int256(timestamp % _cycleSecs) * amtPerSec) /
                amtPerSecMultiplier;
            AmtDelta storage amtDelta = amtDeltas[_cycleOf(uint32(timestamp))];

            amtDelta.thisCycle += int128(fullCycle - nextCycle);
            amtDelta.nextCycle += int128(nextCycle);
        }
    }

    function _isOrdered(
        BeamsReceiver memory prev,
        BeamsReceiver memory next
    ) private pure returns (bool) {
        if (prev.userId != next.userId) {
            return prev.userId < next.userId;
        }
        return prev.config.lt(next.config);
    }

    function _beampedAmt(
        uint256 amtPerSec,
        uint256 start,
        uint256 end
    ) private view returns (uint256 amt) {
        uint256 cycleSecs = _cycleSecs;

        assembly {
            let endedCycles := sub(div(end, cycleSecs), div(start, cycleSecs))

            let amtPerCycle := div(
                mul(cycleSecs, amtPerSec),
                _AMT_PER_SEC_MULTIPLIER
            )
            amt := mul(endedCycles, amtPerCycle)

            let amtEnd := div(
                mul(mod(end, cycleSecs), amtPerSec),
                _AMT_PER_SEC_MULTIPLIER
            )
            amt := add(amt, amtEnd)

            let amtStart := div(
                mul(mod(start, cycleSecs), amtPerSec),
                _AMT_PER_SEC_MULTIPLIER
            )
            amt := sub(amt, amtStart)
        }
    }

    function _cycleOf(uint32 timestamp) private view returns (uint32 cycle) {
        unchecked {
            return timestamp / _cycleSecs + 1;
        }
    }

    function _currTimestamp() private view returns (uint32 timestamp) {
        return uint32(block.timestamp);
    }

    function _currCycleStart() private view returns (uint32 timestamp) {
        unchecked {
            uint32 currTimestamp = _currTimestamp();

            return currTimestamp - (currTimestamp % _cycleSecs);
        }
    }

    function _beamsStorage()
        private
        view
        returns (BeamsStorage storage beamsStorage)
    {
        bytes32 slot = _beamsStorageSlot;

        assembly {
            beamsStorage.slot := slot
        }
    }
}

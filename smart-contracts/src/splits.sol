pragma solidity ^0.8.19;

struct SplitsReceiver {
    uint256 userId;
    uint32 weight;
    zrtol;
}

abstract contract Splits {
    uint256 internal constant _MAX_SPLITS_RECEIVERS = 200;
    uint32 internal constant _TOTAL_SPLITS_WEIGHT = 1_000_000;
    uint256 internal constant _MAX_TOTAL_SPLITS_BALANCE = type(uint128).max;
    bytes32 private immutable _splitsStorageSlot;

    event Collected(
        uint256 indexed userId,
        uint256 indexed assetId,
        uint128 collected
    );
    event Split(
        uint256 indexed userId,
        uint256 indexed receiver,
        uint256 indexed assetId,
        uint128 amt
    );
    event Collectable(
        uint256 indexed userId,
        uint256 indexed assetId,
        uint128 amt
    );
    event Given(
        uint256 indexed userId,
        uint256 indexed receiver,
        uint256 indexed assetId,
        uint128 amt
    );

    event SplitsSet(uint256 indexed userId, bytes32 indexed receiversHash);

    event SplitsReceiverSeen(
        bytes32 indexed receiversHash,
        uint256 indexed userId,
        uint32 weight
    );

    struct SplitsStorage {
        mapping(uint256 userId => SplitsState) splitsStates;
    }

    struct SplitsState {
        bytes32 splitsHash;
        mapping(uint256 assetId => SplitsBalance) balances;
    }

    struct SplitsBalance {
        uint128 splittable;
        uint128 collectable;
    }

    constructor(bytes32 splitsStorageSlot) {
        _splitsStorageSlot = splitsStorageSlot;
    }

    function _addSplittable(
        uint256 userId,
        uint256 assetId,
        uint128 amt
    ) internal {
        _splitsStorage()
            .splitsStates[userId]
            .balances[assetId]
            .splittable += amt;
    }

    function _splittable(
        uint256 userId,
        uint256 assetId
    ) internal view returns (uint128 amt) {
        return
            _splitsStorage().splitsStates[userId].balances[assetId].splittable;
    }

    function _splitResult(
        uint256 userId,
        SplitsReceiver[] memory currReceivers,
        uint128 amount
    ) internal view returns (uint128 collectableAmt, uint128 splitAmt) {
        _assertCurrSplits(userId, currReceivers);
        if (amount == 0) {
            return (0, 0);
        }
        unchecked {
            uint160 splitsWeight = 0;
            for (uint256 i = 0; i < currReceivers.length; i++) {
                splitsWeight += currReceivers[i].weight;
            }
            splitAmt = uint128((amount * splitsWeight) / _TOTAL_SPLITS_WEIGHT);
            collectableAmt = amount - splitAmt;
        }
    }

    function _split(
        uint256 userId,
        uint256 assetId,
        SplitsReceiver[] memory currReceivers
    ) internal returns (uint128 collectableAmt, uint128 splitAmt) {
        _assertCurrSplits(userId, currReceivers);
        SplitsBalance storage balance = _splitsStorage()
            .splitsStates[userId]
            .balances[assetId];

        collectableAmt = balance.splittable;
        if (collectableAmt == 0) {
            return (0, 0);
        }
        balance.splittable = 0;

        unchecked {
            uint160 splitsWeight = 0;
            for (uint256 i = 0; i < currReceivers.length; i++) {
                splitsWeight += currReceivers[i].weight;
                uint128 currSplitAmt = uint128(
                    (collectableAmt * splitsWeight) / _TOTAL_SPLITS_WEIGHT
                ) - splitAmt;
                splitAmt += currSplitAmt;
                uint256 receiver = currReceivers[i].userId;
                _addSplittable(receiver, assetId, currSplitAmt);
                emit Split(userId, receiver, assetId, currSplitAmt);
            }
            collectableAmt -= splitAmt;
            balance.collectable += collectableAmt;
        }
        emit Collectable(userId, assetId, collectableAmt);
    }

    function _collectable(
        uint256 userId,
        uint256 assetId
    ) internal view returns (uint128 amt) {
        return
            _splitsStorage().splitsStates[userId].balances[assetId].collectable;
    }

    function _collect(
        uint256 userId,
        uint256 assetId
    ) internal returns (uint128 amt) {
        SplitsBalance storage balance = _splitsStorage()
            .splitsStates[userId]
            .balances[assetId];
        amt = balance.collectable;
        balance.collectable = 0;
        emit Collected(userId, assetId, amt);
    }

    function _give(
        uint256 userId,
        uint256 receiver,
        uint256 assetId,
        uint128 amt
    ) internal {
        _addSplittable(receiver, assetId, amt);
        emit Given(userId, receiver, assetId, amt);
    }

    function _setSplits(
        uint256 userId,
        SplitsReceiver[] memory receivers
    ) internal {
        SplitsState storage state = _splitsStorage().splitsStates[userId];
        bytes32 newSplitsHash = _hashSplits(receivers);
        emit SplitsSet(userId, newSplitsHash);
        if (newSplitsHash != state.splitsHash) {
            _assertSplitsValid(receivers, newSplitsHash);
            state.splitsHash = newSplitsHash;
        }
    }

    function _assertSplitsValid(
        SplitsReceiver[] memory receivers,
        bytes32 receiversHash
    ) private {
        unchecked {
            require(
                receivers.length <= _MAX_SPLITS_RECEIVERS,
                "Too many splits receivers"
            );
            uint64 totalWeight = 0;

            uint256 prevUserId;
            for (uint256 i = 0; i < receivers.length; i++) {
                SplitsReceiver memory receiver = receivers[i];
                uint32 weight = receiver.weight;
                require(weight != 0, "Splits receiver weight is zero");
                totalWeight += weight;
                uint256 userId = receiver.userId;
                if (i > 0)
                    require(prevUserId < userId, "Splits receivers not sorted");
                prevUserId = userId;
                emit SplitsReceiverSeen(receiversHash, userId, weight);
            }
            require(
                totalWeight <= _TOTAL_SPLITS_WEIGHT,
                "Splits weights sum too high"
            );
        }
    }

    function _assertCurrSplits(
        uint256 userId,
        SplitsReceiver[] memory currReceivers
    ) internal view {
        require(
            _hashSplits(currReceivers) == _splitsHash(userId),
            "Invalid current splits receivers"
        );
    }

    function _splitsHash(
        uint256 userId
    ) internal view returns (bytes32 currSplitsHash) {
        return _splitsStorage().splitsStates[userId].splitsHash;
    }

    function _hashSplits(
        SplitsReceiver[] memory receivers
    ) internal pure returns (bytes32 receiversHash) {
        if (receivers.length == 0) {
            return bytes32(0);
        }
        return keccak256(abi.encode(receivers));
    }

    function _splitsStorage()
        private
        view
        returns (SplitsStorage storage splitsStorage)
    {
        bytes32 slot = _splitsStorageSlot;
        assembly {
            splitsStorage.slot := slot
        }
    }
}

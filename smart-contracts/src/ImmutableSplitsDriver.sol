// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {BeamsHub, SplitsReceiver, UserMetadata} from "./BeamsHub.sol";
import {Managed} from "./Managed.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";

contract ImmutableSplitsDriver is Managed {
    BeamsHub public immutable beamsHub;
    uint32 public immutable driverId;
    uint32 public immutable totalSplitsWeight;
    bytes32 private immutable _counterSlot =
        _erc1967Slot("eip1967.immutableSplitsDriver.storage");

    event CreatedSplits(uint256 indexed userId, bytes32 indexed receiversHash);

    constructor(BeamsHub _beamsHub, uint32 _driverId) {
        beamsHub = _beamsHub;
        driverId = _driverId;
        totalSplitsWeight = _beamsHub.TOTAL_SPLITS_WEIGHT();
    }

    function nextUserId() public view returns (uint256 userId) {
        userId =
            (userId << 224) |
            StorageSlot.getUint256Slot(_counterSlot).value;
    }

    function createSplits(
        SplitsReceiver[] calldata receivers,
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused returns (uint256 userId) {
        userId = nextUserId();
        StorageSlot.getUint256Slot(_counterSlot).value++;
        uint256 weightSum = 0;
        unchecked {
            for (uint256 i = 0; i < receivers.length; i++) {
                weightSum += receivers[i].weight;
            }
        }
        require(
            weightSum == totalSplitsWeight,
            "Invalid total receivers weight"
        );
        emit CreatedSplits(userId, beamsHub.hashSplits(receivers));
        beamsHub.setSplits(userId, receivers);
        if (userMetadata.length > 0)
            beamsHub.emitUserMetadata(userId, userMetadata);
    }
}

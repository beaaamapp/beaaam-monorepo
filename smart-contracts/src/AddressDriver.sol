// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {BeamsHub, BeamsReceiver, IERC20, SafeERC20, SplitsReceiver, UserMetadata} from "./BeamsHub.sol";
import {Managed} from "./Managed.sol";
import {ERC2771Context} from "openzeppelin-contracts/metatx/ERC2771Context.sol";

contract AddressDriver is Managed, ERC2771Context {
    using SafeERC20 for IERC20;

    BeamsHub public immutable beamsHub;
    uint32 public immutable driverId;

    constructor(
        BeamsHub _beamsHub,
        address forwarder,
        uint32 _driverId
    ) ERC2771Context(forwarder) {
        beamsHub = _beamsHub;
        driverId = _driverId;
    }

    function calcUserId(address userAddr) public view returns (uint256 userId) {
        userId = driverId;
        userId = (userId << 224) | uint160(userAddr);
    }

    function _callerUserId() internal view returns (uint256 userId) {
        return calcUserId(_msgSender());
    }

    function collect(
        IERC20 erc20,
        address transferTo
    ) public whenNotPaused returns (uint128 amt) {
        amt = beamsHub.collect(_callerUserId(), erc20);
        if (amt > 0) beamsHub.withdraw(erc20, transferTo, amt);
    }

    function give(
        uint256 receiver,
        IERC20 erc20,
        uint128 amt
    ) public whenNotPaused {
        if (amt > 0) _transferFromCaller(erc20, amt);
        beamsHub.give(_callerUserId(), receiver, erc20, amt);
    }

    function setBeams(
        IERC20 erc20,
        BeamsReceiver[] calldata currReceivers,
        int128 balanceDelta,
        BeamsReceiver[] calldata newReceivers,
        // slither-disable-next-line similar-names
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        address transferTo
    ) public whenNotPaused returns (int128 realBalanceDelta) {
        if (balanceDelta > 0) _transferFromCaller(erc20, uint128(balanceDelta));
        realBalanceDelta = beamsHub.setBeams(
            _callerUserId(),
            erc20,
            currReceivers,
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2
        );
        if (realBalanceDelta < 0)
            beamsHub.withdraw(erc20, transferTo, uint128(-realBalanceDelta));
    }

    function setSplits(
        SplitsReceiver[] calldata receivers
    ) public whenNotPaused {
        beamsHub.setSplits(_callerUserId(), receivers);
    }

    function emitUserMetadata(
        UserMetadata[] calldata userMetadata
    ) public whenNotPaused {
        beamsHub.emitUserMetadata(_callerUserId(), userMetadata);
    }

    function _transferFromCaller(IERC20 erc20, uint128 amt) internal {
        erc20.safeTransferFrom(_msgSender(), address(beamsHub), amt);
    }
}

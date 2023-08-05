// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import {AddressDriver} from "./AddressDriver.sol";
import {Caller} from "./Caller.sol";
import {BeamsHub} from "./BeamsHub.sol";
import {Managed, ManagedProxy} from "./Managed.sol";
import {NFTDriver} from "./NFTDriver.sol";
import {ImmutableSplitsDriver} from "./ImmutableSplitsDriver.sol";

contract Deployer {
    // slither-disable-next-line immutable-states
    address public creator;

    BeamsHub public beamsHub;
    bytes public beamsHubArgs;
    uint32 public beamsHubCycleSecs;
    BeamsHub public beamsHubLogic;
    bytes public beamsHubLogicArgs;
    address public beamsHubAdmin;

    Caller public caller;
    bytes public callerArgs;

    AddressDriver public addressDriver;
    bytes public addressDriverArgs;
    AddressDriver public addressDriverLogic;
    bytes public addressDriverLogicArgs;
    address public addressDriverAdmin;
    uint32 public addressDriverId;

    NFTDriver public nftDriver;
    bytes public nftDriverArgs;
    NFTDriver public nftDriverLogic;
    bytes public nftDriverLogicArgs;
    address public nftDriverAdmin;
    uint32 public nftDriverId;

    ImmutableSplitsDriver public immutableSplitsDriver;
    bytes public immutableSplitsDriverArgs;
    ImmutableSplitsDriver public immutableSplitsDriverLogic;
    bytes public immutableSplitsDriverLogicArgs;
    address public immutableSplitsDriverAdmin;
    uint32 public immutableSplitsDriverId;

    constructor(
        uint32 beamsHubCycleSecs_,
        address beamsHubAdmin_,
        address addressDriverAdmin_,
        address nftDriverAdmin_,
        address immutableSplitsDriverAdmin_
    ) {
        creator = msg.sender;
        _deployBeamsHub(beamsHubCycleSecs_, beamsHubAdmin_);
        _deployCaller();
        _deployAddressDriver(addressDriverAdmin_);
        _deployNFTDriver(nftDriverAdmin_);
        _deployImmutableSplitsDriver(immutableSplitsDriverAdmin_);
    }

    function _deployBeamsHub(
        uint32 beamsHubCycleSecs_,
        address beamsHubAdmin_
    ) internal {
        // Deploy logic
        beamsHubCycleSecs = beamsHubCycleSecs_;
        beamsHubLogicArgs = abi.encode(beamsHubCycleSecs);
        beamsHubLogic = new BeamsHub(beamsHubCycleSecs);
        // Deploy proxy
        beamsHubAdmin = beamsHubAdmin_;
        // slither-disable-next-line reentrancy-benign
        ManagedProxy proxy = new ManagedProxy(beamsHubLogic, beamsHubAdmin);
        beamsHub = BeamsHub(address(proxy));
        beamsHubArgs = abi.encode(beamsHubLogic, beamsHubAdmin);
    }

    function _deployCaller() internal {
        caller = new Caller();
        callerArgs = abi.encode();
    }

    /// @dev Requires BeamsHub and Caller to be deployed
    function _deployAddressDriver(address addressDriverAdmin_) internal {
        // Deploy logic
        address forwarder = address(caller);
        uint32 driverId = beamsHub.nextDriverId();
        addressDriverLogicArgs = abi.encode(beamsHub, forwarder, driverId);
        addressDriverLogic = new AddressDriver(beamsHub, forwarder, driverId);
        // Deploy proxy
        addressDriverAdmin = addressDriverAdmin_;
        // slither-disable-next-line reentrancy-benign
        ManagedProxy proxy = new ManagedProxy(
            addressDriverLogic,
            addressDriverAdmin
        );
        addressDriver = AddressDriver(address(proxy));
        addressDriverArgs = abi.encode(addressDriverLogic, addressDriverAdmin);
        // Register as a driver
        addressDriverId = beamsHub.registerDriver(address(addressDriver));
    }

    /// @dev Requires BeamsHub and Caller to be deployed
    function _deployNFTDriver(address nftDriverAdmin_) internal {
        // Deploy logic
        address forwarder = address(caller);
        uint32 driverId = beamsHub.nextDriverId();
        nftDriverLogicArgs = abi.encode(beamsHub, forwarder, driverId);
        nftDriverLogic = new NFTDriver(beamsHub, forwarder, driverId);
        // Deploy proxy
        nftDriverAdmin = nftDriverAdmin_;
        // slither-disable-next-line reentrancy-benign
        ManagedProxy proxy = new ManagedProxy(nftDriverLogic, nftDriverAdmin);
        nftDriver = NFTDriver(address(proxy));
        nftDriverArgs = abi.encode(nftDriverLogic, nftDriverAdmin);
        // Register as a driver
        nftDriverId = beamsHub.registerDriver(address(nftDriver));
    }

    /// @dev Requires BeamsHub to be deployed
    function _deployImmutableSplitsDriver(
        address immutableSplitsDriverAdmin_
    ) internal {
        // Deploy logic
        uint32 driverId = beamsHub.nextDriverId();
        immutableSplitsDriverLogicArgs = abi.encode(beamsHub, driverId);
        immutableSplitsDriverLogic = new ImmutableSplitsDriver(
            beamsHub,
            driverId
        );
        // Deploy proxy
        immutableSplitsDriverAdmin = immutableSplitsDriverAdmin_;
        // slither-disable-next-line reentrancy-benign
        ManagedProxy proxy = new ManagedProxy(
            immutableSplitsDriverLogic,
            immutableSplitsDriverAdmin
        );
        immutableSplitsDriver = ImmutableSplitsDriver(address(proxy));
        immutableSplitsDriverArgs = abi.encode(
            immutableSplitsDriverLogic,
            immutableSplitsDriverAdmin
        );
        // Register as a driver
        immutableSplitsDriverId = beamsHub.registerDriver(
            address(immutableSplitsDriver)
        );
    }
}

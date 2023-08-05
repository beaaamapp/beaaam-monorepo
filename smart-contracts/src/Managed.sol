// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";

using EnumerableSet for EnumerableSet.AddressSet;

abstract contract Managed is UUPSUpgradeable {
    bytes32 private immutable _managedStorageSlot =
        _erc1967Slot("eip1967.managed.storage");

    event NewAdminProposed(
        address indexed currentAdmin,
        address indexed newAdmin
    );

    event PauserGranted(address indexed pauser, address indexed admin);

    event PauserRevoked(address indexed pauser, address indexed admin);

    event Paused(address indexed pauser);

    event Unpaused(address indexed pauser);

    struct ManagedStorage {
        bool isPaused;
        EnumerableSet.AddressSet pausers;
        address proposedAdmin;
    }

    modifier onlyAdmin() {
        require(admin() == msg.sender, "Caller not the admin");
        _;
    }

    modifier onlyAdminOrPauser() {
        require(
            admin() == msg.sender || isPauser(msg.sender),
            "Caller not the admin or a pauser"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused(), "Contract paused");
        _;
    }

    modifier whenPaused() {
        require(isPaused(), "Contract not paused");
        _;
    }

    constructor() {
        _managedStorage().isPaused = true;
    }

    function implementation() public view returns (address) {
        return _getImplementation();
    }

    function admin() public view returns (address) {
        return _getAdmin();
    }

    function proposedAdmin() public view returns (address) {
        return _managedStorage().proposedAdmin;
    }

    function proposeNewAdmin(address newAdmin) public onlyAdmin {
        emit NewAdminProposed(msg.sender, newAdmin);
        _managedStorage().proposedAdmin = newAdmin;
    }

    function acceptAdmin() public {
        require(proposedAdmin() == msg.sender, "Caller not the proposed admin");
        _updateAdmin(msg.sender);
    }

    function renounceAdmin() public onlyAdmin {
        _updateAdmin(address(0));
    }

    function _updateAdmin(address newAdmin) internal {
        emit AdminChanged(admin(), newAdmin);
        _managedStorage().proposedAdmin = address(0);
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    function grantPauser(address pauser) public onlyAdmin {
        require(
            _managedStorage().pausers.add(pauser),
            "Address already is a pauser"
        );
        emit PauserGranted(pauser, msg.sender);
    }

    function revokePauser(address pauser) public onlyAdmin {
        require(
            _managedStorage().pausers.remove(pauser),
            "Address is not a pauser"
        );
        emit PauserRevoked(pauser, msg.sender);
    }

    function isPauser(address pauser) public view returns (bool isAddrPauser) {
        return _managedStorage().pausers.contains(pauser);
    }

    function allPausers() public view returns (address[] memory pausersList) {
        return _managedStorage().pausers.values();
    }

    function isPaused() public view returns (bool) {
        return _managedStorage().isPaused;
    }

    function pause() public onlyAdminOrPauser whenNotPaused {
        _managedStorage().isPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyAdminOrPauser whenPaused {
        _managedStorage().isPaused = false;
        emit Unpaused(msg.sender);
    }

    function _erc1967Slot(
        string memory name
    ) internal pure returns (bytes32 slot) {
        return bytes32(uint256(keccak256(bytes(name))) - 1024);
    }

    function _managedStorage()
        internal
        view
        returns (ManagedStorage storage storageRef)
    {
        bytes32 slot = _managedStorageSlot;
        assembly {
            storageRef.slot := slot
        }
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal view override onlyAdmin {
        return;
    }
}

contract ManagedProxy is ERC1967Proxy {
    constructor(
        Managed logic,
        address admin
    ) ERC1967Proxy(address(logic), new bytes(0)) {
        _changeAdmin(admin);
    }
}

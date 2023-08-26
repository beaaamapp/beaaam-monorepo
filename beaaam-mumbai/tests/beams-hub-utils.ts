import { newMockEvent } from "matchstick-as"
import { ethereum, Address, Bytes, BigInt } from "@graphprotocol/graph-ts"
import {
  AdminChanged,
  BeaconUpgraded,
  BeamsReceiverSeen,
  BeamsSet,
  Collectable,
  Collected,
  DriverAddressUpdated,
  DriverRegistered,
  Given,
  NewAdminProposed,
  Paused,
  PauserGranted,
  PauserRevoked,
  ReceivedBeams,
  Split,
  SplitsReceiverSeen,
  SplitsSet,
  SqueezedBeams,
  Unpaused,
  Upgraded,
  UserMetadataEmitted,
  Withdrawn
} from "../generated/beamsHub/beamsHub"

export function createAdminChangedEvent(
  previousAdmin: Address,
  newAdmin: Address
): AdminChanged {
  let adminChangedEvent = changetype<AdminChanged>(newMockEvent())

  adminChangedEvent.parameters = new Array()

  adminChangedEvent.parameters.push(
    new ethereum.EventParam(
      "previousAdmin",
      ethereum.Value.fromAddress(previousAdmin)
    )
  )
  adminChangedEvent.parameters.push(
    new ethereum.EventParam("newAdmin", ethereum.Value.fromAddress(newAdmin))
  )

  return adminChangedEvent
}

export function createBeaconUpgradedEvent(beacon: Address): BeaconUpgraded {
  let beaconUpgradedEvent = changetype<BeaconUpgraded>(newMockEvent())

  beaconUpgradedEvent.parameters = new Array()

  beaconUpgradedEvent.parameters.push(
    new ethereum.EventParam("beacon", ethereum.Value.fromAddress(beacon))
  )

  return beaconUpgradedEvent
}

export function createBeamsReceiverSeenEvent(
  receiversHash: Bytes,
  userId: BigInt,
  config: BigInt
): BeamsReceiverSeen {
  let beamsReceiverSeenEvent = changetype<BeamsReceiverSeen>(newMockEvent())

  beamsReceiverSeenEvent.parameters = new Array()

  beamsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam(
      "receiversHash",
      ethereum.Value.fromFixedBytes(receiversHash)
    )
  )
  beamsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  beamsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam("config", ethereum.Value.fromUnsignedBigInt(config))
  )

  return beamsReceiverSeenEvent
}

export function createBeamsSetEvent(
  userId: BigInt,
  assetId: BigInt,
  receiversHash: Bytes,
  beamsHistoryHash: Bytes,
  balance: BigInt,
  maxEnd: BigInt
): BeamsSet {
  let beamsSetEvent = changetype<BeamsSet>(newMockEvent())

  beamsSetEvent.parameters = new Array()

  beamsSetEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  beamsSetEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  beamsSetEvent.parameters.push(
    new ethereum.EventParam(
      "receiversHash",
      ethereum.Value.fromFixedBytes(receiversHash)
    )
  )
  beamsSetEvent.parameters.push(
    new ethereum.EventParam(
      "beamsHistoryHash",
      ethereum.Value.fromFixedBytes(beamsHistoryHash)
    )
  )
  beamsSetEvent.parameters.push(
    new ethereum.EventParam(
      "balance",
      ethereum.Value.fromUnsignedBigInt(balance)
    )
  )
  beamsSetEvent.parameters.push(
    new ethereum.EventParam("maxEnd", ethereum.Value.fromUnsignedBigInt(maxEnd))
  )

  return beamsSetEvent
}

export function createCollectableEvent(
  userId: BigInt,
  assetId: BigInt,
  amt: BigInt
): Collectable {
  let collectableEvent = changetype<Collectable>(newMockEvent())

  collectableEvent.parameters = new Array()

  collectableEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  collectableEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  collectableEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )

  return collectableEvent
}

export function createCollectedEvent(
  userId: BigInt,
  assetId: BigInt,
  collected: BigInt
): Collected {
  let collectedEvent = changetype<Collected>(newMockEvent())

  collectedEvent.parameters = new Array()

  collectedEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  collectedEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  collectedEvent.parameters.push(
    new ethereum.EventParam(
      "collected",
      ethereum.Value.fromUnsignedBigInt(collected)
    )
  )

  return collectedEvent
}

export function createDriverAddressUpdatedEvent(
  driverId: BigInt,
  oldDriverAddr: Address,
  newDriverAddr: Address
): DriverAddressUpdated {
  let driverAddressUpdatedEvent = changetype<DriverAddressUpdated>(
    newMockEvent()
  )

  driverAddressUpdatedEvent.parameters = new Array()

  driverAddressUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "driverId",
      ethereum.Value.fromUnsignedBigInt(driverId)
    )
  )
  driverAddressUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "oldDriverAddr",
      ethereum.Value.fromAddress(oldDriverAddr)
    )
  )
  driverAddressUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newDriverAddr",
      ethereum.Value.fromAddress(newDriverAddr)
    )
  )

  return driverAddressUpdatedEvent
}

export function createDriverRegisteredEvent(
  driverId: BigInt,
  driverAddr: Address
): DriverRegistered {
  let driverRegisteredEvent = changetype<DriverRegistered>(newMockEvent())

  driverRegisteredEvent.parameters = new Array()

  driverRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "driverId",
      ethereum.Value.fromUnsignedBigInt(driverId)
    )
  )
  driverRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "driverAddr",
      ethereum.Value.fromAddress(driverAddr)
    )
  )

  return driverRegisteredEvent
}

export function createGivenEvent(
  userId: BigInt,
  receiver: BigInt,
  assetId: BigInt,
  amt: BigInt
): Given {
  let givenEvent = changetype<Given>(newMockEvent())

  givenEvent.parameters = new Array()

  givenEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  givenEvent.parameters.push(
    new ethereum.EventParam(
      "receiver",
      ethereum.Value.fromUnsignedBigInt(receiver)
    )
  )
  givenEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  givenEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )

  return givenEvent
}

export function createNewAdminProposedEvent(
  currentAdmin: Address,
  newAdmin: Address
): NewAdminProposed {
  let newAdminProposedEvent = changetype<NewAdminProposed>(newMockEvent())

  newAdminProposedEvent.parameters = new Array()

  newAdminProposedEvent.parameters.push(
    new ethereum.EventParam(
      "currentAdmin",
      ethereum.Value.fromAddress(currentAdmin)
    )
  )
  newAdminProposedEvent.parameters.push(
    new ethereum.EventParam("newAdmin", ethereum.Value.fromAddress(newAdmin))
  )

  return newAdminProposedEvent
}

export function createPausedEvent(pauser: Address): Paused {
  let pausedEvent = changetype<Paused>(newMockEvent())

  pausedEvent.parameters = new Array()

  pausedEvent.parameters.push(
    new ethereum.EventParam("pauser", ethereum.Value.fromAddress(pauser))
  )

  return pausedEvent
}

export function createPauserGrantedEvent(
  pauser: Address,
  admin: Address
): PauserGranted {
  let pauserGrantedEvent = changetype<PauserGranted>(newMockEvent())

  pauserGrantedEvent.parameters = new Array()

  pauserGrantedEvent.parameters.push(
    new ethereum.EventParam("pauser", ethereum.Value.fromAddress(pauser))
  )
  pauserGrantedEvent.parameters.push(
    new ethereum.EventParam("admin", ethereum.Value.fromAddress(admin))
  )

  return pauserGrantedEvent
}

export function createPauserRevokedEvent(
  pauser: Address,
  admin: Address
): PauserRevoked {
  let pauserRevokedEvent = changetype<PauserRevoked>(newMockEvent())

  pauserRevokedEvent.parameters = new Array()

  pauserRevokedEvent.parameters.push(
    new ethereum.EventParam("pauser", ethereum.Value.fromAddress(pauser))
  )
  pauserRevokedEvent.parameters.push(
    new ethereum.EventParam("admin", ethereum.Value.fromAddress(admin))
  )

  return pauserRevokedEvent
}

export function createReceivedBeamsEvent(
  userId: BigInt,
  assetId: BigInt,
  amt: BigInt,
  receivableCycles: BigInt
): ReceivedBeams {
  let receivedBeamsEvent = changetype<ReceivedBeams>(newMockEvent())

  receivedBeamsEvent.parameters = new Array()

  receivedBeamsEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  receivedBeamsEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  receivedBeamsEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )
  receivedBeamsEvent.parameters.push(
    new ethereum.EventParam(
      "receivableCycles",
      ethereum.Value.fromUnsignedBigInt(receivableCycles)
    )
  )

  return receivedBeamsEvent
}

export function createSplitEvent(
  userId: BigInt,
  receiver: BigInt,
  assetId: BigInt,
  amt: BigInt
): Split {
  let splitEvent = changetype<Split>(newMockEvent())

  splitEvent.parameters = new Array()

  splitEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  splitEvent.parameters.push(
    new ethereum.EventParam(
      "receiver",
      ethereum.Value.fromUnsignedBigInt(receiver)
    )
  )
  splitEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  splitEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )

  return splitEvent
}

export function createSplitsReceiverSeenEvent(
  receiversHash: Bytes,
  userId: BigInt,
  weight: BigInt
): SplitsReceiverSeen {
  let splitsReceiverSeenEvent = changetype<SplitsReceiverSeen>(newMockEvent())

  splitsReceiverSeenEvent.parameters = new Array()

  splitsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam(
      "receiversHash",
      ethereum.Value.fromFixedBytes(receiversHash)
    )
  )
  splitsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  splitsReceiverSeenEvent.parameters.push(
    new ethereum.EventParam("weight", ethereum.Value.fromUnsignedBigInt(weight))
  )

  return splitsReceiverSeenEvent
}

export function createSplitsSetEvent(
  userId: BigInt,
  receiversHash: Bytes
): SplitsSet {
  let splitsSetEvent = changetype<SplitsSet>(newMockEvent())

  splitsSetEvent.parameters = new Array()

  splitsSetEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  splitsSetEvent.parameters.push(
    new ethereum.EventParam(
      "receiversHash",
      ethereum.Value.fromFixedBytes(receiversHash)
    )
  )

  return splitsSetEvent
}

export function createSqueezedBeamsEvent(
  userId: BigInt,
  assetId: BigInt,
  senderId: BigInt,
  amt: BigInt,
  beamsHistoryHashes: Array<Bytes>
): SqueezedBeams {
  let squeezedBeamsEvent = changetype<SqueezedBeams>(newMockEvent())

  squeezedBeamsEvent.parameters = new Array()

  squeezedBeamsEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  squeezedBeamsEvent.parameters.push(
    new ethereum.EventParam(
      "assetId",
      ethereum.Value.fromUnsignedBigInt(assetId)
    )
  )
  squeezedBeamsEvent.parameters.push(
    new ethereum.EventParam(
      "senderId",
      ethereum.Value.fromUnsignedBigInt(senderId)
    )
  )
  squeezedBeamsEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )
  squeezedBeamsEvent.parameters.push(
    new ethereum.EventParam(
      "beamsHistoryHashes",
      ethereum.Value.fromFixedBytesArray(beamsHistoryHashes)
    )
  )

  return squeezedBeamsEvent
}

export function createUnpausedEvent(pauser: Address): Unpaused {
  let unpausedEvent = changetype<Unpaused>(newMockEvent())

  unpausedEvent.parameters = new Array()

  unpausedEvent.parameters.push(
    new ethereum.EventParam("pauser", ethereum.Value.fromAddress(pauser))
  )

  return unpausedEvent
}

export function createUpgradedEvent(implementation: Address): Upgraded {
  let upgradedEvent = changetype<Upgraded>(newMockEvent())

  upgradedEvent.parameters = new Array()

  upgradedEvent.parameters.push(
    new ethereum.EventParam(
      "implementation",
      ethereum.Value.fromAddress(implementation)
    )
  )

  return upgradedEvent
}

export function createUserMetadataEmittedEvent(
  userId: BigInt,
  key: Bytes,
  value: Bytes
): UserMetadataEmitted {
  let userMetadataEmittedEvent = changetype<UserMetadataEmitted>(newMockEvent())

  userMetadataEmittedEvent.parameters = new Array()

  userMetadataEmittedEvent.parameters.push(
    new ethereum.EventParam("userId", ethereum.Value.fromUnsignedBigInt(userId))
  )
  userMetadataEmittedEvent.parameters.push(
    new ethereum.EventParam("key", ethereum.Value.fromFixedBytes(key))
  )
  userMetadataEmittedEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromBytes(value))
  )

  return userMetadataEmittedEvent
}

export function createWithdrawnEvent(
  erc20: Address,
  receiver: Address,
  amt: BigInt
): Withdrawn {
  let withdrawnEvent = changetype<Withdrawn>(newMockEvent())

  withdrawnEvent.parameters = new Array()

  withdrawnEvent.parameters.push(
    new ethereum.EventParam("erc20", ethereum.Value.fromAddress(erc20))
  )
  withdrawnEvent.parameters.push(
    new ethereum.EventParam("receiver", ethereum.Value.fromAddress(receiver))
  )
  withdrawnEvent.parameters.push(
    new ethereum.EventParam("amt", ethereum.Value.fromUnsignedBigInt(amt))
  )

  return withdrawnEvent
}

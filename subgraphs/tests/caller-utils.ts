import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Authorized,
  CalledAs,
  CalledSigned,
  EIP712DomainChanged,
  NonceSet,
  Unauthorized,
  UnauthorizedAll
} from "../generated/Caller/Caller"

export function createAuthorizedEvent(
  sender: Address,
  authorized: Address
): Authorized {
  let authorizedEvent = changetype<Authorized>(newMockEvent())

  authorizedEvent.parameters = new Array()

  authorizedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  authorizedEvent.parameters.push(
    new ethereum.EventParam(
      "authorized",
      ethereum.Value.fromAddress(authorized)
    )
  )

  return authorizedEvent
}

export function createCalledAsEvent(
  sender: Address,
  authorized: Address
): CalledAs {
  let calledAsEvent = changetype<CalledAs>(newMockEvent())

  calledAsEvent.parameters = new Array()

  calledAsEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  calledAsEvent.parameters.push(
    new ethereum.EventParam(
      "authorized",
      ethereum.Value.fromAddress(authorized)
    )
  )

  return calledAsEvent
}

export function createCalledSignedEvent(
  sender: Address,
  nonce: BigInt
): CalledSigned {
  let calledSignedEvent = changetype<CalledSigned>(newMockEvent())

  calledSignedEvent.parameters = new Array()

  calledSignedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  calledSignedEvent.parameters.push(
    new ethereum.EventParam("nonce", ethereum.Value.fromUnsignedBigInt(nonce))
  )

  return calledSignedEvent
}

export function createEIP712DomainChangedEvent(): EIP712DomainChanged {
  let eip712DomainChangedEvent = changetype<EIP712DomainChanged>(newMockEvent())

  eip712DomainChangedEvent.parameters = new Array()

  return eip712DomainChangedEvent
}

export function createNonceSetEvent(
  sender: Address,
  newNonce: BigInt
): NonceSet {
  let nonceSetEvent = changetype<NonceSet>(newMockEvent())

  nonceSetEvent.parameters = new Array()

  nonceSetEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  nonceSetEvent.parameters.push(
    new ethereum.EventParam(
      "newNonce",
      ethereum.Value.fromUnsignedBigInt(newNonce)
    )
  )

  return nonceSetEvent
}

export function createUnauthorizedEvent(
  sender: Address,
  unauthorized: Address
): Unauthorized {
  let unauthorizedEvent = changetype<Unauthorized>(newMockEvent())

  unauthorizedEvent.parameters = new Array()

  unauthorizedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  unauthorizedEvent.parameters.push(
    new ethereum.EventParam(
      "unauthorized",
      ethereum.Value.fromAddress(unauthorized)
    )
  )

  return unauthorizedEvent
}

export function createUnauthorizedAllEvent(sender: Address): UnauthorizedAll {
  let unauthorizedAllEvent = changetype<UnauthorizedAll>(newMockEvent())

  unauthorizedAllEvent.parameters = new Array()

  unauthorizedAllEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )

  return unauthorizedAllEvent
}

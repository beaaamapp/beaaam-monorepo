import {
  Authorized as AuthorizedEvent,
  CalledAs as CalledAsEvent,
  CalledSigned as CalledSignedEvent,
  EIP712DomainChanged as EIP712DomainChangedEvent,
  NonceSet as NonceSetEvent,
  Unauthorized as UnauthorizedEvent,
  UnauthorizedAll as UnauthorizedAllEvent
} from "../generated/Caller/Caller"
import {
  Authorized,
  CalledAs,
  CalledSigned,
  EIP712DomainChanged,
  NonceSet,
  Unauthorized,
  UnauthorizedAll
} from "../generated/schema"

export function handleAuthorized(event: AuthorizedEvent): void {
  let entity = new Authorized(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender
  entity.authorized = event.params.authorized

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleCalledAs(event: CalledAsEvent): void {
  let entity = new CalledAs(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender
  entity.authorized = event.params.authorized

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleCalledSigned(event: CalledSignedEvent): void {
  let entity = new CalledSigned(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender
  entity.nonce = event.params.nonce

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleEIP712DomainChanged(
  event: EIP712DomainChangedEvent
): void {
  let entity = new EIP712DomainChanged(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleNonceSet(event: NonceSetEvent): void {
  let entity = new NonceSet(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender
  entity.newNonce = event.params.newNonce

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUnauthorized(event: UnauthorizedEvent): void {
  let entity = new Unauthorized(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender
  entity.unauthorized = event.params.unauthorized

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUnauthorizedAll(event: UnauthorizedAllEvent): void {
  let entity = new UnauthorizedAll(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.sender = event.params.sender

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

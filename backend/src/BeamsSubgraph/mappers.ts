import Utils from '../utils';
import type {
	BeamsReceiverSeenEvent,
	BeamsSetEvent,
	SplitsEntry,
	UserAssetConfig,
	UserMetadataEntry,
	SplitEvent,
	ReceivedBeamsEvent,
	GivenEvent,
	CollectedEvent,
	SqueezedBeamsEvent
} from './types';
import type * as SubgraphTypes from './generated/graphql-types';

/** @internal */
export const mapUserAssetConfigToDto = (userAssetConfig: SubgraphTypes.UserAssetConfig): UserAssetConfig => ({
	id: userAssetConfig.id,
	assetId: BigInt(userAssetConfig.assetId),
	beamsEntries: userAssetConfig.beamsEntries?.map((d) => ({
		id: d.id,
		userId: d.userId,
		config: BigInt(d.config)
	})),
	balance: BigInt(userAssetConfig.balance),
	amountCollected: BigInt(userAssetConfig.amountCollected),
	lastUpdatedBlockTimestamp: BigInt(userAssetConfig.lastUpdatedBlockTimestamp)
});

/** @internal */
export const mapSplitEntryToDto = (splitEntry: SubgraphTypes.SplitsEntry): SplitsEntry => ({
	id: splitEntry.id,
	userId: splitEntry.userId,
	senderId: splitEntry.sender.id,
	weight: BigInt(splitEntry.weight)
});

/** @internal */
export const mapBeamsSetEventToDto = (beamsSetEvent: SubgraphTypes.BeamsSetEvent): BeamsSetEvent => ({
	id: beamsSetEvent.id,
	userId: beamsSetEvent.userId,
	assetId: BigInt(beamsSetEvent.assetId),
	beamsReceiverSeenEvents: beamsSetEvent.beamsReceiverSeenEvents?.map((r) => ({
		id: r.id,
		receiverUserId: r.receiverUserId,
		config: BigInt(r.config)
	})),
	beamsHistoryHash: beamsSetEvent.beamsHistoryHash,
	balance: BigInt(beamsSetEvent.balance),
	blockTimestamp: BigInt(beamsSetEvent.blockTimestamp),
	maxEnd: BigInt(beamsSetEvent.maxEnd),
	receiversHash: beamsSetEvent.receiversHash
});

/** @internal */
export const mapSplitEventToDto = (splitEvent: SubgraphTypes.SplitEvent): SplitEvent => ({
	id: splitEvent.id,
	amount: BigInt(splitEvent.amt),
	assetId: BigInt(splitEvent.assetId),
	blockTimestamp: BigInt(splitEvent.blockTimestamp),
	receiverId: splitEvent.receiverId,
	userId: splitEvent.userId
});

/** @internal */
export const mapReceivedBeamsEventToDto = (
	receivedBeamsEvent: SubgraphTypes.ReceivedBeamsEvent
): ReceivedBeamsEvent => ({
	id: receivedBeamsEvent.id,
	amount: BigInt(receivedBeamsEvent.amt),
	assetId: BigInt(receivedBeamsEvent.assetId),
	blockTimestamp: BigInt(receivedBeamsEvent.blockTimestamp),
	receivableCycles: BigInt(receivedBeamsEvent.receivableCycles),
	userId: receivedBeamsEvent.userId
});

/** @internal */
export const mapCollectedEventToDto = (collectedEvent: SubgraphTypes.CollectedEvent): CollectedEvent => ({
	id: collectedEvent.id,
	collected: BigInt(collectedEvent.collected),
	assetId: BigInt(collectedEvent.assetId),
	blockTimestamp: BigInt(collectedEvent.blockTimestamp),
	userId: collectedEvent.user.id
});

/** @internal */
export const mapSqueezedBeamsToDto = (squeezedBeamsEvent: SubgraphTypes.SqueezedBeamsEvent): SqueezedBeamsEvent => ({
	amount: BigInt(squeezedBeamsEvent.amt),
	assetId: BigInt(squeezedBeamsEvent.assetId),
	blockTimestamp: BigInt(squeezedBeamsEvent.blockTimestamp),
	id: squeezedBeamsEvent.id,
	senderId: squeezedBeamsEvent.senderId,
	userId: squeezedBeamsEvent.userId,
	beamsHistoryHashes: squeezedBeamsEvent.beamsHistoryHashes
});

/** @internal */
export const mapGivenEventToDto = (givenEvent: SubgraphTypes.GivenEvent): GivenEvent => ({
	id: givenEvent.id,
	amount: BigInt(givenEvent.amt),
	assetId: BigInt(givenEvent.assetId),
	blockTimestamp: BigInt(givenEvent.blockTimestamp),
	receiverUserId: givenEvent.receiverUserId,
	userId: givenEvent.userId
});

/** @internal */
export const mapBeamsReceiverSeenEventToDto = (
	beamsReceiverSeenEvent: SubgraphTypes.BeamsReceiverSeenEvent
): BeamsReceiverSeenEvent => ({
	id: beamsReceiverSeenEvent.id,
	config: BigInt(beamsReceiverSeenEvent.config),
	senderUserId: BigInt(beamsReceiverSeenEvent.senderUserId),
	receiverUserId: BigInt(beamsReceiverSeenEvent.receiverUserId),
	beamsSetEvent: {
		id: beamsReceiverSeenEvent.beamsSetEvent.id,
		assetId: BigInt(beamsReceiverSeenEvent.beamsSetEvent.assetId),
		receiversHash: beamsReceiverSeenEvent.beamsSetEvent.receiversHash
	},
	blockTimestamp: BigInt(beamsReceiverSeenEvent.blockTimestamp)
});

/** @internal */
export const mapUserMetadataEventToDto = (userMetadata: SubgraphTypes.UserMetadataEvent): UserMetadataEntry => {
	const { key, value } = Utils.Metadata.convertMetadataBytesToString(userMetadata);

	return {
		key,
		value,
		id: userMetadata.id,
		userId: userMetadata.userId,
		lastUpdatedBlockTimestamp: BigInt(userMetadata.lastUpdatedBlockTimestamp)
	};
};

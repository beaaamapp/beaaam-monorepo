export type UserAssetConfig = {
	id: string;
	assetId: bigint;
	beamsEntries: {
		id: string;
		userId: string;
		config: bigint;
	}[];
	balance: bigint;
	amountCollected: bigint;
	lastUpdatedBlockTimestamp: bigint;
};

export type SplitsEntry = {
	id: string;
	userId: string;
	weight: bigint;
	senderId: string;
};

export type BeamsSetEvent = {
	id: string;
	userId: string;
	assetId: bigint;
	beamsReceiverSeenEvents: {
		id: string;
		receiverUserId: string;
		config: bigint;
	}[];
	beamsHistoryHash: string;
	balance: bigint;
	blockTimestamp: bigint;
	maxEnd: bigint;
	receiversHash: string;
};

export type CollectedEvent = {
	id: string;
	userId: string;
	assetId: bigint;
	collected: bigint;
	blockTimestamp: bigint;
};

export type SqueezedBeamsEvent = {
	amount: bigint;
	assetId: bigint;
	blockTimestamp: bigint;
	id: string;
	senderId: string;
	userId: string;
	beamsHistoryHashes: string[];
};

export type SplitEvent = {
	id: string;
	amount: bigint;
	assetId: bigint;
	blockTimestamp: bigint;
	receiverId: string;
	userId: string;
};

export type ReceivedBeamsEvent = {
	id: string;
	amount: bigint;
	assetId: bigint;
	blockTimestamp: bigint;
	receivableCycles: bigint;
	userId: string;
};

export type GivenEvent = {
	id: string;
	amount: bigint;
	assetId: bigint;
	blockTimestamp: bigint;
	receiverUserId: string;
	userId: string;
};

export type BeamsReceiverSeenEvent = {
	id: string;
	config: bigint;
	senderUserId: bigint;
	receiverUserId: bigint;
	beamsSetEvent: {
		id: string;
		assetId: bigint;
		receiversHash: string;
	};
	blockTimestamp: bigint;
};

export type UserMetadataEntry = {
	id: string;
	key: string;
	value: string;
	userId: string;
	lastUpdatedBlockTimestamp: bigint;
};

export type NftSubAccount = {
	tokenId: string;
	ownerAddress: string;
};

export type BeamsSetEventWithFullReceivers = {
	currentReceivers: {
		id: string;
		receiverUserId: string;
		config: bigint;
	}[];
} & BeamsSetEvent;

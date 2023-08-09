import type { PopulatedTransaction } from 'ethers';
import type { BeamsHistoryStruct } from '../../contracts/BeamsHub';

export {
	BeamsReceiverStruct,
	SplitsReceiverStruct,
	BeamsHistoryStruct,
	BeamsHubInterface,
	UserMetadataStruct
} from '../../contracts/BeamsHub';
export { NFTDriverInterface } from '../../contracts/NFTDriver';
export { CallStruct, CallerInterface } from '../../contracts/Caller';
export { AddressDriverInterface } from '../../contracts/AddressDriver';
export { ImmutableSplitsDriverInterface } from '../../contracts/ImmutableSplitsDriver';

export type BeamsReceiverConfig = {
	/** An arbitrary number used to identify a beam. When setting a config, it must be greater than or equal to `0`. It's a part of the configuration but the protocol doesn't use it. */
	beamId: bigint;

	/** The UNIX timestamp (in seconds) when beamping should start. When setting a config, it must be greater than or equal to `0`. If set to `0`, the contract will use the timestamp when beams are configured. */
	start: bigint;

	/** The duration (in seconds) of beamping. When setting a config, it must be greater than or equal to `0`. If set to `0`, the contract will beam until the balance runs out. */
	duration: bigint;

	/** The amount per second being beamped. When setting a config, it must be in the smallest unit (e.g., Wei), greater than `0` **and be multiplied by `10 ^ 9`** (`constants.AMT_PER_SEC_MULTIPLIER`). */
	amountPerSec: bigint;
};

export type NetworkConfig = {
	CHAIN: string;
	DEPLOYMENT_TIME: string;
	COMMIT_HASH: string;
	WALLET: string;
	WALLET_NONCE: string;
	DEPLOYER: string;
	BEAMS_HUB: string;
	BEAMS_HUB_CYCLE_SECONDS: string;
	BEAMS_HUB_LOGIC: string;
	BEAMS_HUB_ADMIN: string;
	CALLER: string;
	ADDRESS_DRIVER: string;
	ADDRESS_DRIVER_LOGIC: string;
	ADDRESS_DRIVER_ADMIN: string;
	ADDRESS_DRIVER_ID: string;
	NFT_DRIVER: string;
	NFT_DRIVER_LOGIC: string;
	NFT_DRIVER_ADMIN: string;
	NFT_DRIVER_ID: string;
	IMMUTABLE_SPLITS_DRIVER: string;
	IMMUTABLE_SPLITS_DRIVER_LOGIC: string;
	IMMUTABLE_SPLITS_DRIVER_ADMIN: string;
	IMMUTABLE_SPLITS_DRIVER_ID: string;
	SUBGRAPH_URL: string;
};

export type CycleInfo = {
	cycleDurationSecs: bigint;
	currentCycleSecs: bigint;
	currentCycleStartDate: Date;
	nextCycleStartDate: Date;
};

export type BeamsReceiver = { userId: string; config: BeamsReceiverConfig };

export type Preset = PopulatedTransaction[];

export type UserMetadata = {
	key: string;
	value: string;
};

export type SqueezeArgs = {
	userId: string;
	tokenAddress: string;
	senderId: string;
	historyHash: string;
	beamsHistory: BeamsHistoryStruct[];
};

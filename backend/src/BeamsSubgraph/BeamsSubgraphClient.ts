/* eslint-disable no-constant-condition */
/* eslint-disable no-await-in-loop */
import type { BigNumberish } from 'ethers';
import { ethers } from 'ethers';
import constants from '../constants';
import { nameOf, formatBeamsReceivers } from '../common/internals';
import Utils from '../utils';
import { validateAddress } from '../common/validators';
import { BeamsErrors } from '../common/BeamsError';
import * as gql from './gql';
import type * as SubgraphTypes from './generated/graphql-types';
import type {
	BeamsSetEvent,
	SplitsEntry,
	UserAssetConfig,
	BeamsReceiverSeenEvent,
	UserMetadataEntry,
	NftSubAccount,
	SplitEvent,
	ReceivedBeamsEvent,
	GivenEvent,
	CollectedEvent,
	SqueezedBeamsEvent,
	BeamsSetEventWithFullReceivers
} from './types';
import {
	mapCollectedEventToDto,
	mapBeamsReceiverSeenEventToDto,
	mapBeamsSetEventToDto,
	mapGivenEventToDto,
	mapReceivedBeamsEventToDto,
	mapSplitEntryToDto,
	mapSplitEventToDto,
	mapSqueezedBeamsToDto,
	mapUserAssetConfigToDto,
	mapUserMetadataEventToDto
} from './mappers';
import type { BeamsHistoryStruct, BeamsReceiverStruct, SqueezeArgs } from '../common/types';
import { reconcileBeamsSetReceivers } from './utils';

/**
 * A client for querying the Beams Subgraph.
 */
export default class BeamsSubgraphClient {
	#chainId!: number;
	/** Returns the chain ID the `BeamsSubgraphClient` is connected to. */
	public get chainId() {
		return this.#chainId;
	}

	#apiUrl!: string;
	/** Returns the `BeamsSubgraphClient`'s API URL. */
	public get apiUrl() {
		return this.#apiUrl;
	}

	private constructor() {}

	/**
	 * Creates a new immutable `BeamsSubgraphClient` instance.
	 *
	 * @param  {string} chainId The chain ID.
	 * @param  {string|undefined} customApiUrl Overrides the subgraph's `apiUrl`.
	 * If it's `undefined` (default value), the `apiUrl` will be automatically selected based on the `chainId`.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `chainId` is missing.
	 * @throws {@link BeamsErrors.unsupportedNetworkError} if the `chainId` is not supported.
	 * @returns The new `BeamsSubgraphClient` instance.
	 */
	public static create(chainId: number, customApiUrl?: string): BeamsSubgraphClient {
		if (!chainId) {
			throw BeamsErrors.argumentMissingError(
				`Could not create a new 'BeamsSubgraphClient': ${nameOf({ chainId })} is missing.`,
				nameOf({ chainId })
			);
		}

		if (!Utils.Network.isSupportedChain(chainId)) {
			throw BeamsErrors.unsupportedNetworkError(
				`Could not create a new 'BeamsSubgraphClient': chain ID '${chainId}' is not supported.`,
				chainId
			);
		}

		const subgraphClient = new BeamsSubgraphClient();

		subgraphClient.#chainId = chainId;
		subgraphClient.#apiUrl = customApiUrl ?? Utils.Network.configs[subgraphClient.#chainId].SUBGRAPH_URL;

		return subgraphClient;
	}

	/**
	 * Returns the beams configuration for the given user and asset.
	 * @param  {string} userId The user ID.
	 * @param  {BigNumberish} assetId The asset ID.
	 * @returns A `Promise` which resolves to the user's beams configuration, or `null` if the configuration is not found.
	 * @throws {@link BeamsErrors.argumentMissingError} if any of the required parameters is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getUserAssetConfigById(userId: string, assetId: BigNumberish): Promise<UserAssetConfig | null> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get user asset config: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		if (!assetId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get user asset config: ${nameOf({ assetId })} is missing.`,
				nameOf({ assetId })
			);
		}

		type QueryResponse = {
			userAssetConfig: SubgraphTypes.UserAssetConfig;
		};

		const response = await this.query<QueryResponse>(gql.getUserAssetConfigById, {
			configId: `${userId}-${assetId}`
		});

		const userAssetConfig = response?.data?.userAssetConfig;

		return userAssetConfig ? mapUserAssetConfigToDto(userAssetConfig) : null;
	}

	/**
	 * Returns a list of beams configurations for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's beams configurations.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getAllUserAssetConfigsByUserId(
		userId: string,
		skip: number = 0,
		first: number = 100
	): Promise<UserAssetConfig[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get user asset configs: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			user: {
				assetConfigs: SubgraphTypes.UserAssetConfig[];
			};
		};

		const response = await this.query<QueryResponse>(gql.getAllUserAssetConfigsByUserId, { userId, skip, first });

		return response?.data?.user?.assetConfigs?.map(mapUserAssetConfigToDto) || [];
	}

	/**
	 * Returns the splits configuration for the give user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's splits configuration.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getSplitsConfigByUserId(userId: string, skip: number = 0, first: number = 100): Promise<SplitsEntry[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get splits config: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			user: {
				splitsEntries: SubgraphTypes.SplitsEntry[];
			};
		};

		const response = await this.query<QueryResponse>(gql.getSplitsConfigByUserId, { userId, skip, first });

		return response?.data?.user?.splitsEntries?.map(mapSplitEntryToDto) || [];
	}

	/**
	 * Returns a list of `Split` entries for the given user.
	 * @param  {string} receiverUserId The receiver's user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the receivers's `Split` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `receiverUserId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getSplitEntriesByReceiverUserId(
		receiverUserId: string,
		skip: number = 0,
		first: number = 100
	): Promise<SplitsEntry[]> {
		if (!receiverUserId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'split' events: ${nameOf({ receiverUserId })} is missing.`,
				nameOf({ receiverUserId })
			);
		}

		type QueryResponse = {
			splitsEntries: SubgraphTypes.SplitsEntry[];
		};

		const response = await this.query<QueryResponse>(gql.getSplitEntriesByReceiverUserId, {
			receiverUserId,
			skip,
			first
		});

		return response?.data?.splitsEntries?.map(mapSplitEntryToDto) || [];
	}

	/**
	 * Returns a list of `BeamsSet` events for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `BeamsSet` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getBeamsSetEventsByUserId(
		userId: string,
		skip: number = 0,
		first: number = 100
	): Promise<BeamsSetEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'beam set' events: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			beamsSetEvents: SubgraphTypes.BeamsSetEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getBeamsSetEventsByUserId, { userId, skip, first });

		return response?.data?.beamsSetEvents?.map(mapBeamsSetEventToDto) || [];
	}

	/**
	 * Returns a list of `BeamsReceiverSeen` events for the given receiver.
	 * @param  {string} receiverUserId The receiver's user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the receivers's `BeamsReceiverSeen` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `receiverUserId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getBeamsReceiverSeenEventsByReceiverId(
		receiverUserId: string,
		skip: number = 0,
		first: number = 100
	): Promise<BeamsReceiverSeenEvent[]> {
		if (!receiverUserId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get streaming users: ${nameOf({ receiverUserId })} is missing.`,
				nameOf({ receiverUserId })
			);
		}

		type QueryResponse = {
			beamsReceiverSeenEvents: SubgraphTypes.BeamsReceiverSeenEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getBeamsReceiverSeenEventsByReceiverId, {
			receiverUserId,
			skip,
			first
		});
		const beamsReceiverSeenEvents = response?.data?.beamsReceiverSeenEvents;

		if (!beamsReceiverSeenEvents?.length) {
			return [];
		}

		return beamsReceiverSeenEvents.map(mapBeamsReceiverSeenEventToDto);
	}

	/**
	 * Returns the users that stream funds to the given receiver.
	 * @param  {string} receiverUserId The receiver's user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the users that stream funds to the given receiver.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `receiverUserId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getUsersStreamingToUser(
		receiverUserId: string,
		skip: number = 0,
		first: number = 100
	): Promise<bigint[]> {
		if (!receiverUserId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get streaming users: ${nameOf({ receiverUserId })} is missing.`,
				nameOf({ receiverUserId })
			);
		}

		const beamReceiverSeenEvents = await this.getBeamsReceiverSeenEventsByReceiverId(receiverUserId, skip, first);

		const uniqueSenders = beamReceiverSeenEvents.reduce((unique: bigint[], o: BeamsReceiverSeenEvent) => {
			if (!unique.some((id: bigint) => id === o.senderUserId)) {
				unique.push(o.senderUserId);
			}
			return unique;
		}, []);

		return uniqueSenders;
	}

	/**
	 * Returns the history of user metadata updates for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {string} key The metadata key.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's metadata.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getMetadataHistory(
		userId: string,
		key?: string,
		skip: number = 0,
		first: number = 100
	): Promise<UserMetadataEntry[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get user metadata: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			userMetadataEvents: SubgraphTypes.UserMetadataEvent[];
		};

		let response: { data: QueryResponse };

		if (key) {
			response = await this.query<QueryResponse>(gql.getMetadataHistoryByUserAndKey, {
				userId,
				key: `${Utils.Metadata.keyFromString(key)}`,
				skip,
				first
			});
		} else {
			response = await this.query<QueryResponse>(gql.getMetadataHistoryByUser, { userId, skip, first });
		}

		const userMetadataEvents = response?.data?.userMetadataEvents;

		return userMetadataEvents ? userMetadataEvents.map(mapUserMetadataEventToDto) : [];
	}

	/**
	 * Returns the latest metadata update for the given `userId`-`key` pair.
	 * @param  {string} userId The user ID.
	 * @param  {string} key The metadata key.
	 * @returns A `Promise` which resolves to the user's metadata, or `null` if not found.
	 * @throws {@link BeamsErrors.argumentMissingError} if any of the required parameter is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getLatestUserMetadata(userId: string, key: string): Promise<UserMetadataEntry | null> {
		if (!userId) {
			throw BeamsErrors.argumentError(`Could not get user metadata: '${nameOf({ key })}' is missing.`);
		}

		if (!key) {
			throw BeamsErrors.argumentError(`Could not get user metadata: '${nameOf({ key })}' is missing.`);
		}

		type QueryResponse = {
			userMetadataByKey: SubgraphTypes.UserMetadataEvent;
		};

		const response = await this.query<QueryResponse>(gql.getLatestUserMetadata, {
			id: `${userId}-${key}`
		});

		const userMetadataEvent = response?.data?.userMetadataByKey;

		return userMetadataEvent ? mapUserMetadataEventToDto(userMetadataEvent) : null;
	}

	/**
	 * Returns a list of NFT sub accounts for the given owner.
	 * @param  {string} ownerAddress The owner's address.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the owner's NFT sub accounts.
	 * @throws {@link BeamsErrors.addressError} if the `ownerAddress` is not valid.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getNftSubAccountsByOwner(
		ownerAddress: string,
		skip: number = 0,
		first: number = 100
	): Promise<NftSubAccount[]> {
		validateAddress(ownerAddress);

		type QueryResponse = {
			nftsubAccounts: SubgraphTypes.NftSubAccount[];
		};

		const response = await this.query<QueryResponse>(gql.getNftSubAccountsByOwner, {
			ownerAddress: ethers.utils.getAddress(ownerAddress),
			skip,
			first
		});

		const nftSubAccounts = response?.data?.nftsubAccounts;

		return nftSubAccounts
			? nftSubAccounts.map((s) => ({
					tokenId: s.id,
					ownerAddress: ethers.utils.getAddress(s.ownerAddress)
			  }))
			: [];
	}

	/**
	 * Returns the NFT sub account owner for the given token ID.
	 * @param  {string} tokenId The token ID.
	 * @returns A `Promise` which resolves to the NFT sub account owner, or `null` if not found.
	 * @throws {@link BeamsErrors.argumentError} if the `tokenId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getNftSubAccountOwnerByTokenId(tokenId: string): Promise<NftSubAccount | null> {
		if (!tokenId) {
			throw BeamsErrors.argumentError(`Could not get NFT sub account: tokenId is missing.`);
		}

		type QueryResponse = {
			nftsubAccount: SubgraphTypes.NftSubAccount;
		};

		const response = await this.query<QueryResponse>(gql.getNftSubAccountOwnerByTokenId, { tokenId });

		const nftSubAccount = response?.data?.nftsubAccount;

		return nftSubAccount
			? { tokenId: nftSubAccount.id, ownerAddress: ethers.utils.getAddress(nftSubAccount.ownerAddress) }
			: null;
	}

	/**
	 * Returns a list of token IDs that are associated with the given app.
	 * @param  {string} associatedApp The name/ID of the app to retrieve accounts for.
	 *
	 * **Tip**: you might want to use `Utils.UserMetadata.valueFromString` to create your `associatedApp` argument from a `string`.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the account IDs.
	 * @throws {@link BeamsErrors.argumentError} if the `associatedApp` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getNftSubAccountIdsByApp(
		associatedApp: string,
		skip: number = 0,
		first: number = 100
	): Promise<string[]> {
		if (!associatedApp) {
			throw BeamsErrors.argumentError(`Could not get user metadata: ${nameOf({ associatedApp })} is missing.`);
		}

		type QueryResponse = {
			userMetadataEvents: SubgraphTypes.UserMetadataEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getMetadataHistoryByKeyAndValue, {
			key: constants.ASSOCIATED_APP_KEY_BYTES,
			value: Utils.Metadata.valueFromString(associatedApp),
			skip,
			first
		});

		const userMetadataEvents = response?.data?.userMetadataEvents;

		const uniqueUserIds = userMetadataEvents?.reduce((unique: string[], o: SubgraphTypes.UserMetadataEvent) => {
			if (!unique.some((id: string) => id === o.userId)) {
				unique.push(o.userId);
			}
			return unique;
		}, []);

		return uniqueUserIds || [];
	}

	/**
	 * Returns a list of `Collected` events for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `Collected` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getCollectedEventsByUserId(
		userId: string,
		skip: number = 0,
		first: number = 100
	): Promise<CollectedEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'split' events: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			collectedEvents: SubgraphTypes.CollectedEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getCollectedEventsByUserId, { userId, skip, first });

		return response?.data?.collectedEvents?.map(mapCollectedEventToDto) || [];
	}

	/**
	 * Returns the user's `SqueezedBeams` events.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `SqueezedBeams` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getSqueezedBeamsEventsByUserId(
		userId: string,
		skip: number = 0,
		first: number = 100
	): Promise<SqueezedBeamsEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentError(`Could not get 'squeezed Beams' events: ${nameOf({ userId })} is missing.`);
		}

		type QueryResponse = {
			squeezedBeamsEvents: SubgraphTypes.SqueezedBeamsEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getSqueezedBeamsEventsByUserId, { userId, skip, first });

		return response?.data?.squeezedBeamsEvents?.map(mapSqueezedBeamsToDto) || [];
	}

	/**
	 * Returns a list of `Split` events for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `Split` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getSplitEventsByUserId(userId: string, skip: number = 0, first: number = 100): Promise<SplitEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'split' events: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			splitEvents: SubgraphTypes.SplitEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getSplitEventsByUserId, { userId, skip, first });

		return response?.data?.splitEvents?.map(mapSplitEventToDto) || [];
	}

	/**
	 * Returns a list of `Split` events for the given receiver.
	 * @param  {string} receiverUserId The receiver user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the receiver's `Split` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `receiverUserId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getSplitEventsByReceiverUserId(
		receiverUserId: string,
		skip: number = 0,
		first: number = 100
	): Promise<SplitEvent[]> {
		if (!receiverUserId) {
			throw BeamsErrors.argumentError(`Could not get 'split' events: ${nameOf({ receiverUserId })} is missing.`);
		}

		type QueryResponse = {
			splitEvents: SubgraphTypes.SplitEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getSplitEventsByReceiverUserId, {
			receiverUserId,
			skip,
			first
		});

		return response?.data?.splitEvents?.map(mapSplitEventToDto) || [];
	}

	/**
	 * Returns a list of `ReceivedBeams` events for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `ReceivedBeams` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getReceivedBeamsEventsByUserId(
		userId: string,
		skip: number = 0,
		first: number = 100
	): Promise<ReceivedBeamsEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'received beams' events: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			receivedBeamsEvents: SubgraphTypes.ReceivedBeamsEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getReceivedBeamsEventsByUserId, { userId, skip, first });

		return response?.data?.receivedBeamsEvents?.map(mapReceivedBeamsEventToDto) || [];
	}

	/**
	 * Returns a list of `Given` events for the given user.
	 * @param  {string} userId The user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the user's `Given` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getGivenEventsByUserId(userId: string, skip: number = 0, first: number = 100): Promise<GivenEvent[]> {
		if (!userId) {
			throw BeamsErrors.argumentMissingError(
				`Could not get 'given' events: ${nameOf({ userId })} is missing.`,
				nameOf({ userId })
			);
		}

		type QueryResponse = {
			givenEvents: SubgraphTypes.GivenEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getGivenEventsByUserId, { userId, skip, first });

		return response?.data?.givenEvents?.map(mapGivenEventToDto) || [];
	}

	/**
	 * Returns a list of `Given` events for the given receiver.
	 * @param  {string} receiverUserId The receiver user ID.
	 * @param  {number} skip The number of database entries to skip. Defaults to `0`.
	 * @param  {number} first The number of database entries to take. Defaults to `100`.
	 * @returns A `Promise` which resolves to the receiver's `Given` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `receiverId` is missing.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getGivenEventsByReceiverUserId(
		receiverUserId: string,
		skip: number = 0,
		first: number = 100
	): Promise<GivenEvent[]> {
		if (!receiverUserId) {
			throw BeamsErrors.argumentError(`Could not get 'given' events: ${nameOf({ receiverUserId })} is missing.`);
		}

		type QueryResponse = {
			givenEvents: SubgraphTypes.GivenEvent[];
		};

		const response = await this.query<QueryResponse>(gql.getGivenEventsByReceiverUserId, {
			receiverUserId,
			skip,
			first
		});

		return response?.data?.givenEvents?.map(mapGivenEventToDto) || [];
	}

	/**
	 * Calculates the arguments for squeezing all Beams up to "now" for the given sender and token.
	 *
	 * **Important**: This method might fail if two Beams updates were performed in a single block.
	 * because the order of the Beams configurations returned by the Subgraph is not guaranteed for such cases.
	 * The transaction will fail in the gas estimation phase, so no gas will be wasted.
	 * @see `BeamsHubClient.squeezeBeams` method for more.
	 * @param  {string} userId The ID of the user receiving beams to squeeze funds for.
	 * @param  {BigNumberish} senderId The ID of the user sending beams to squeeze funds from.
	 * @param  {string} tokenAddress The ERC20 token address.
	 * @returns A `Promise` which resolves to the `BeamsHubClient.squeezeBeams` arguments.
	 */
	public async getArgsForSqueezingAllBeams(
		userId: string,
		senderId: string,
		tokenAddress: string
	): Promise<SqueezeArgs> {
		// Get all `BeamsSet` events (beams configurations) for the sender.
		const allBeamsSetEvents: BeamsSetEvent[] = [];
		let skip = 0;
		const first = 500;
		while (true) {
			const iterationEvents = await this.getBeamsSetEventsByUserId(senderId, skip, first);

			allBeamsSetEvents.push(...iterationEvents);

			if (!iterationEvents?.length || iterationEvents.length < first) {
				break;
			}

			skip += first;
		}

		const filtered = allBeamsSetEvents
			// Remove any duplicates (limitation of skip-first pagination).
			.reduce((unique: BeamsSetEvent[], o: BeamsSetEvent) => {
				if (!unique.some((ev: BeamsSetEvent) => ev.id === o.id)) {
					unique.push(o);
				}
				return unique;
			}, [])
			// Filter only the events for the token-to-be-squeezed.
			.filter((e) => e.assetId === Utils.Asset.getIdFromAddress(ethers.utils.getAddress(tokenAddress)));

		const squeezableBeamsSetEvents: BeamsSetEventWithFullReceivers[] =
			// Add the `receivers` field to each event.
			reconcileBeamsSetReceivers(filtered)
				// Sort by `blockTimestamp` DESC - the first ones will be the most recent.
				.sort((a, b) => Number(b.blockTimestamp) - Number(a.blockTimestamp));

		const beamsSetEventsToSqueeze: BeamsSetEventWithFullReceivers[] = [];

		// Iterate over all events.
		if (squeezableBeamsSetEvents?.length) {
			for (let i = 0; i < squeezableBeamsSetEvents.length; i++) {
				const beamsConfiguration = squeezableBeamsSetEvents[i];

				// Keep the beams configurations of the current cycle.
				const { currentCycleStartDate } = Utils.Cycle.getInfo(this.#chainId);
				const eventTimestamp = new Date(Number(beamsConfiguration.blockTimestamp * BigInt(1000)));
				if (eventTimestamp >= currentCycleStartDate) {
					beamsSetEventsToSqueeze.push(beamsConfiguration);
				}
				// Get the last event of the previous cycle.
				else {
					beamsSetEventsToSqueeze.push(beamsConfiguration);
					break;
				}
			}
		}

		// The last (oldest) event added, provides the hash prior to the BeamsHistory (or 0, if there was only one event).
		const historyHash =
			beamsSetEventsToSqueeze[beamsSetEventsToSqueeze.length - 1]?.beamsHistoryHash || ethers.constants.HashZero;

		// Transform the events into `BeamsHistory` objects.
		const beamsHistory: BeamsHistoryStruct[] = beamsSetEventsToSqueeze
			?.map((beamsSetEvent) => {
				// By default a configuration should *not* be squeezed.
				let shouldSqueeze = false;

				// Iterate over all event's receivers.
				for (let i = 0; i < beamsSetEvent.currentReceivers.length; i++) {
					const receiver = beamsSetEvent.currentReceivers[i];

					// Mark as squeezable only the events that beam to the `userId`; the others should not be squeezed.
					if (receiver.receiverUserId === userId) {
						shouldSqueeze = true;
						// Break, because beams receivers are unique.
						break;
					}
				}

				const historyItem: BeamsHistoryStruct = {
					beamsHash: shouldSqueeze ? ethers.constants.HashZero : beamsSetEvent.receiversHash, // If it's non-zero, `receivers` must be empty.
					receivers: shouldSqueeze // If it's non-empty, `beamsHash` must be 0.
						? beamsSetEvent.currentReceivers.map((r) => ({
								userId: r.receiverUserId,
								config: r.config
						  }))
						: [],
					updateTime: beamsSetEvent.blockTimestamp,
					maxEnd: beamsSetEvent.maxEnd
				};

				return historyItem;
			})
			// Reverse from DESC to ASC order, as the protocol expects.
			.reverse();

		// Return the parameters required by the `squeezeBeams` methods.
		return { userId, tokenAddress, senderId, historyHash, beamsHistory };
	}

	/**
	 * Returns a list of senders for which beams can _potentially_ be squeezed, for the given receiver.
	 *
	 * The returned senders have set up a configuration that beams to the given `receiver`
	 * but **it's not guaranteed that the sender is still beamping to this sender**.
	 * The sender might be out of funds, for example.
	 * @param  {string} receiverId The receiver's user ID.
	 * @returns A `Promise` which resolves to a `Record` with keys being the sender IDs and values the asset (ERC20 token) IDs.
	 * @throws {BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async filterSqueezableSenders(receiverId: string): Promise<Record<string, string[]>> {
		type ApiResponse = {
			beamsReceiverSeenEvents: BeamsReceiverSeenEvent[];
		};

		// Get all `BeamsReceiverSeen` events for the given receiver.
		const beamsReceiverSeenEvents: BeamsReceiverSeenEvent[] = [];
		let skip = 0;
		const first = 500;
		while (true) {
			const response = await this.query<ApiResponse>(gql.getBeamsReceiverSeenEventsByReceiverId, {
				receiverId,
				skip,
				first
			});
			const iterationEvents = response?.data?.beamsReceiverSeenEvents;

			beamsReceiverSeenEvents.push(...iterationEvents);

			if (!iterationEvents?.length || iterationEvents.length < first) {
				break;
			}

			skip += first;
		}

		if (!beamsReceiverSeenEvents?.length) {
			return {};
		}

		// Remove any duplicates.
		const uniqueEvents = beamsReceiverSeenEvents.reduce(
			(unique: BeamsReceiverSeenEvent[], o: BeamsReceiverSeenEvent) => {
				if (!unique.some((ev: BeamsReceiverSeenEvent) => ev.id === o.id)) {
					unique.push(o);
				}
				return unique;
			},
			[]
		);

		const squeezableSenders: Record<string, string[]> = {}; // key: senderId, value: [asset1Id, asset2Id, ...]

		// Iterate over all `BeamsReceiverSeen` events.
		for (let i = 0; i < uniqueEvents.length; i++) {
			const { senderUserId, beamsSetEvent } = uniqueEvents[i];

			if (!squeezableSenders[senderUserId.toString()]) {
				squeezableSenders[senderUserId.toString()] = [];
			}

			if (!squeezableSenders[senderUserId.toString()].includes(beamsSetEvent.assetId.toString())) {
				squeezableSenders[senderUserId.toString()].push(beamsSetEvent.assetId.toString());
			}
		}

		return squeezableSenders;
	}

	/**
	 * Returns the current Beams receivers for the given configuration.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 * @returns A `Promise` which resolves to the user's `Collected` events.
	 * @throws {@link BeamsErrors.argumentMissingError} if the current Beams receivers.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async getCurrentBeamsReceivers(userId: string, tokenAddress: string): Promise<BeamsReceiverStruct[]> {
		let beamsSetEvents: BeamsSetEvent[] = [];
		let skip = 0;
		const first = 500;

		// Get all `BeamsSet` events.
		while (true) {
			const iterationBeamsSetEvents = await this.getBeamsSetEventsByUserId(userId, skip, first);

			// Filter by asset.
			const tokenBeamsSetEvents = iterationBeamsSetEvents.filter(
				(e) => e.assetId === Utils.Asset.getIdFromAddress(tokenAddress)
			);

			beamsSetEvents.push(...tokenBeamsSetEvents);

			if (!iterationBeamsSetEvents?.length || iterationBeamsSetEvents.length < first) {
				break;
			}

			skip += first;
		}

		if (!beamsSetEvents?.length) {
			return [];
		}

		// Sort by `blockTimestamp` DESC - the first ones will be the most recent.
		beamsSetEvents = beamsSetEvents.sort((a, b) => Number(b.blockTimestamp) - Number(a.blockTimestamp));

		// Return the most recent event's receivers formatted as expected by the protocol.
		return formatBeamsReceivers(
			beamsSetEvents[0].beamsReceiverSeenEvents.map((d) => ({
				config: d.config,
				userId: d.receiverUserId
			}))
		);
	}

	/**
	 * Executes the given query against the Beams Subgraph.
	 * @example <caption>Example usage for querying `Split` events.</caption>
		type SplitEvent = {
			id: string;
			amount: bigint;
			assetId: bigint;
			blockTimestamp: bigint;
			receiverId: string;
			userId: string;
		}

 	 	type QueryResponse = {
			splitEvents: SplitEvent[];
		};

		export const getSplitEventsByUserId = `#graphql
			query getSplitEventsByUserId($userId: String!, $skip: Int, $first: Int) {
  			splitEvents(where: {userId: $userId}, skip: $skip, first: $first) {
					id
					userId
					receiverId
					assetId
					amt
					blockTimestamp
				}
			}
		`;

		const userId = "1";
		const skip = 0;
		const first = 100;

		const response = await beamsSubgraphClient.query<QueryResponse>(getSplitEventsByUserId, { userId, skip, first });

		const events = response?.data?.splitEvents?.map(mapSplitEventToDto) || [];

	 * @param  {string} query The GraphQL query.
	 * @param  {unknown} variables The GraphQL query variables.
	 * @returns A `Promise` which resolves to the expected data.
	 * @throws {@link BeamsErrors.subgraphQueryError} if the query fails.
	 */
	public async query<T = unknown>(query: string, variables: unknown): Promise<{ data: T }> {
		const resp = await fetch(this.apiUrl, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ query, variables }, (_, value) => (typeof value === 'bigint' ? value.toString() : value))
		});

		if (resp.status >= 200 && resp.status <= 299) {
			const responseContent = (await resp.json()) as { data?: T; errors?: any[] };

			if (responseContent?.errors?.length && responseContent.errors.length > 0) {
				throw BeamsErrors.subgraphQueryError(`Subgraph query failed: ${JSON.stringify(responseContent.errors[0])}`);
			}

			return responseContent as { data: T };
		}

		throw BeamsErrors.subgraphQueryError(`Subgraph query failed: ${resp.statusText}`);
	}
}

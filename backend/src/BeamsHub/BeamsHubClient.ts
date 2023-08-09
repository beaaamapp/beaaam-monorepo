import type { Provider } from '@ethersproject/providers';
import type { BigNumberish, ContractTransaction, Signer } from 'ethers';
import { BigNumber } from 'ethers';
import type { BeamsHistoryStruct, BeamsReceiverStruct, SplitsReceiverStruct } from '../common/types';
import { ensureSignerExists, formatSplitReceivers, isNullOrUndefined, nameOf } from '../common/internals';
import {
	validateAddress,
	validateClientProvider,
	validateClientSigner,
	validateBeamsReceivers,
	validateReceiveBeamsInput,
	validateSplitInput,
	validateSplitsReceivers,
	validateSqueezeBeamsInput
} from '../common/validators';
import Utils from '../utils';
import type { BeamsHub } from '../../contracts';
import { BeamsHub__factory } from '../../contracts';
import { BeamsErrors } from '../common/BeamsError';
import type { CollectableBalance, BeamsState, ReceivableBalance, SplitResult, SplittableBalance } from './types';

/**
 * A client for interacting with the {@link https://github.com/malawadd/beaaam/blob/main/smart-contracts/src/BeamsHub.sol  BeamsHub}.
 */
export default class BeamsHubClient {
	#driver!: BeamsHub;
	#contractAddress!: string;
	#provider!: Provider;
	#signer: Signer | undefined;

	/** Returns the `BeamsHubClient`'s `provider`. */
	public get provider(): Provider {
		return this.#provider;
	}

	/**
	 * Returns the `BeamsHubClient`'s `signer`.
	 *
	 * This is the user to which the `BeamsHubClient` is linked and manages Beams.
	 *
	 * Note that for read-only client instances created with the {@link createReadonly} method it returns `undefined`.
	 */
	public get signer(): Signer | undefined {
		return this.#signer;
	}

	/** Returns the `BeamsHub`'s address to which the `BeamsHubClient` is connected. */
	public get contractAddress(): string {
		return this.#contractAddress;
	}

	private constructor() {}

	/**
	 * Creates a new immutable `BeamsHubClient` instance.
	 * @param  {Provider} provider The network provider. It cannot be changed after creation.
	 *
	 * The `provider` must be connected to one of the following supported networks:
	 * - 'mainnet': chain ID `1`
	 * - 'goerli': chain ID `5`
	 * - 'polygon-mumbai': chain ID `80001`
	 * @param  {Provider|undefined} signer The singer used to sign transactions. It cannot be changed after creation.
	 *
	 * **Important**: If the `signer` is _not_ connected to a provider it will try to connect to the `provider`, else it will use the `signer.provider`.
	 * @param  {string|undefined} customDriverAddress Overrides the `NFTDriver` contract address.
	 * If it's `undefined` (default value), the address will be automatically selected based on the `provider`'s network.
	 * @returns A `Promise` which resolves to the new client instance.
	 * @throws {@link BeamsErrors.initializationError} if the client initialization fails.
	 */
	public static async create(
		provider: Provider,
		signer?: Signer,
		customDriverAddress?: string
	): Promise<BeamsHubClient> {
		try {
			await validateClientProvider(provider, Utils.Network.SUPPORTED_CHAINS);

			if (signer) {
				if (!signer.provider) {
					// eslint-disable-next-line no-param-reassign
					signer = signer.connect(provider);
				}

				await validateClientSigner(signer, Utils.Network.SUPPORTED_CHAINS);
			}

			const network = await provider.getNetwork();
			const contractAddress = customDriverAddress ?? Utils.Network.configs[network.chainId].BEAMS_HUB;

			const client = new BeamsHubClient();

			client.#signer = signer;
			client.#provider = provider;
			client.#contractAddress = contractAddress;
			client.#driver = BeamsHub__factory.connect(contractAddress, signer ?? provider);
			return client;
		} catch (error: any) {
			throw BeamsErrors.initializationError(`Could not create 'BeamsHubClient': ${error.message}`);
		}
	}

	/**
	 * Returns the cycle length in seconds.
	 * @returns A `Promise` which resolves to the cycle seconds.
	 */
	public cycleSecs(): Promise<number> {
		return this.#driver.cycleSecs();
	}

	/**
	 * Returns the total amount currently stored in `BeamsHub` for the given token.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @returns A `Promise` which resolves to the balance of the token.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 */
	public async getTokenBalance(tokenAddress: string): Promise<bigint> {
		validateAddress(tokenAddress);

		const totalBalance = await this.#driver.totalBalance(tokenAddress);

		return totalBalance.toBigInt();
	}

	/**
	 * Returns the count of cycles from which beams can be collected.
	 * This method can be used to detect if there are too many cycles to analyze in a single transaction.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @returns A `Promise` which resolves to the number of receivable cycles.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 */
	public receivableCyclesCount(userId: string, tokenAddress: string): Promise<number> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get receivable cycles count: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		return this.#driver.receivableBeamsCycles(userId, tokenAddress);
	}

	/**
	 * Calculates the user's receivable balance for the given token.
	 * Receivable balance contains the funds other users beam to and is updated once every cycle.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {BigNumberish} maxCycles The maximum number of received beams cycles. Must be greater than `0`.
	 * If too low, receiving will be cheap, but may not cover many cycles.
	 * If too high, receiving may become too expensive to fit in a single transaction.
	 * @returns A `Promise` which resolves to the receivable balance.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.argumentError} if `maxCycles` is not valid.
	 */
	public async getReceivableBalanceForUser(
		userId: string,
		tokenAddress: string,
		maxCycles: BigNumberish
	): Promise<ReceivableBalance> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get receivable balance: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		if (!maxCycles || maxCycles < 0) {
			throw BeamsErrors.argumentError(
				`Could not get receivable balance: '${nameOf({ maxCycles })}' is missing.`,
				nameOf({ maxCycles }),
				maxCycles
			);
		}

		const receivableBalance = await this.#driver.receiveBeamsResult(userId, tokenAddress, maxCycles);

		return {
			tokenAddress,
			receivableAmount: receivableBalance.toBigInt()
		};
	}

	/**
	 * Receives user's beams.
	 * Calling this function does not collect but makes the funds ready to split and collect.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {BigNumberish} maxCycles The maximum number of received beams cycles. Must be greater than `0`.
	 * If too low, receiving will be cheap, but may not cover many cycles.
	 * If too high, receiving may become too expensive to fit in a single transaction.
	 * @returns A `Promise` which resolves to the contract transaction.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 * @throws {@link BeamsErrors.argumentError} if `maxCycles` is not valid.
	 */
	public receiveBeams(userId: string, tokenAddress: string, maxCycles: BigNumberish): Promise<ContractTransaction> {
		ensureSignerExists(this.#signer);
		validateReceiveBeamsInput(userId, tokenAddress, maxCycles);

		return this.#driver.receiveBeams(userId, tokenAddress, maxCycles);
	}

	/**
	 * Receives beams from the currently running cycle from a single sender.
	 * It doesn't receive beams from the previous, finished cycles, to do that use `receiveBeams`.
	 * Squeezed funds won't be received in the next calls to `squeezeBeams` or `receiveBeams`.
	 * Only funds beamped before `block.timestamp` can be squeezed.
	 *
	 * **Tip**: you might want to use `BeamsSubgraphClient.getArgsForSqueezingAllBeams` to easily populate the arguments for squeezing all Beams up to "now".
	 * @param  {string} userId The ID of the user receiving beams to squeeze funds for.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {BigNumberish} senderId The ID of the user sending beams to squeeze funds from.
	 * @param  {string} historyHash The sender's history hash which was valid right before they set up the sequence of configurations described by `beamsHistory`.
	 * @param  {BigNumberish} beamsHistory The sequence of the sender's beams configurations.
	 * It can start at an arbitrary past configuration, but must describe all the configurations
	 * which have been used since then including the current one, in the chronological order.
	 * Only beams described by `beamsHistory` will be squeezed.
	 * If `beamsHistory` entries have no receivers, they won't be squeezed.
	 * @returns A `Promise` which resolves to the contract transaction.
	 * @throws {BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {BeamsErrors.argumentMissingError} if any of the required parameters is missing.
	 */
	public squeezeBeams(
		userId: string,
		tokenAddress: string,
		senderId: BigNumberish,
		historyHash: string,
		beamsHistory: BeamsHistoryStruct[]
	): Promise<ContractTransaction> {
		validateSqueezeBeamsInput(userId, tokenAddress, senderId, historyHash, beamsHistory);

		return this.#driver.squeezeBeams(userId, tokenAddress, senderId, historyHash, beamsHistory);
	}

	/**
	 * Calculates the user's squeezable balance.
	 * Squeezable balance contains the funds that can be received from the currently running cycle from a single sender.
	 * @param  {string} userId The ID of the user receiving beams to squeeze funds for.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {string} senderId The ID of the user sending beams to squeeze funds from.
	 * @param  {string} historyHash The sender's history hash which was valid right before
	 * they set up the sequence of configurations described by `beamsHistory`.
	 * @param  {BeamsHistoryStruct[]} beamsHistory The sequence of the sender's beams configurations.
	 * @returns A `Promise` which resolves to the the squeezable balance.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if any of the required parameters is missing.
	 */
	public async getSqueezableBalance(
		userId: string,
		tokenAddress: string,
		senderId: string,
		historyHash: string,
		beamsHistory: BeamsHistoryStruct[]
	): Promise<bigint> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get squeezable balance: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		if (isNullOrUndefined(senderId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get squeezable balance: '${nameOf({ senderId })}' is missing.`,
				nameOf({ senderId })
			);
		}

		if (isNullOrUndefined(historyHash)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get squeezable balance: '${nameOf({ historyHash })}' is missing.`,
				nameOf({ historyHash })
			);
		}

		if (isNullOrUndefined(beamsHistory)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get squeezable balance: '${nameOf({ beamsHistory })}' is missing.`,
				nameOf({ beamsHistory })
			);
		}

		const squeezableBalance = await this.#driver.squeezeBeamsResult(
			userId,
			tokenAddress,
			senderId,
			historyHash,
			beamsHistory
		);

		return squeezableBalance.toBigInt();
	}

	/**
	 * Returns the user's splittable balance for the given token.
	 * Splittable balance contains the user's received but not split yet funds.
	 * @param  {string} userId user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @returns A `Promise` which resolves to the the splittable balance.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 */
	public async getSplittableBalanceForUser(userId: string, tokenAddress: string): Promise<SplittableBalance> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get splittable balance: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		const splittableBalance = await this.#driver.splittable(userId, tokenAddress);

		return {
			tokenAddress,
			splittableAmount: splittableBalance.toBigInt()
		};
	}

	/**
	 * Calculates the result of splitting an amount using the user's current splits configuration.
	 * @param  {string} userId The user ID.
	 * @param  {SplitsReceiverStruct[]} currentReceivers The current splits receivers.
	 * @param  {BigNumberish[]} amount The amount being split. It must be greater than `0`.
	 * @returns A `Promise` which resolves to the split result.
	 * @throws {@link BeamsErrors.argumentMissingError} if any of the required parameters is missing.
	 * @throws {@link BeamsErrors.argumentError} if `amount` or `currentReceivers`' is not valid.
	 * @throws {@link BeamsErrors.splitsReceiverError} if any of the `currentReceivers` is not valid.
	 */
	public async getSplitResult(
		userId: string,
		currentReceivers: SplitsReceiverStruct[],
		amount: BigNumberish
	): Promise<SplitResult> {
		validateSplitsReceivers(currentReceivers);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get split result: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		if (!amount || amount < 0) {
			throw BeamsErrors.argumentError(
				`Could not get split result: '${nameOf({ amount })}' must be greater than 0.`,
				nameOf({ amount }),
				amount
			);
		}

		const { collectableAmt, splitAmt } = await this.#driver.splitResult(userId, currentReceivers, amount);

		return {
			collectableAmount: collectableAmt.toBigInt(),
			splitAmount: splitAmt.toBigInt()
		};
	}

	/**
	 * Splits user's received but not split yet funds among receivers.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {SplitsReceiverStruct[]} currentReceivers The current splits receivers.
	 * @returns A `Promise` which resolves to the contract transaction.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if `currentReceivers` are missing.
	 * @throws {@link BeamsErrors.argumentError} if `currentReceivers`' count exceeds the max allowed splits receivers.
	 * @throws {@link BeamsErrors.splitsReceiverError} if any of the `currentReceivers` is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 */
	public async split(
		userId: BigNumberish,
		tokenAddress: string,
		currentReceivers: SplitsReceiverStruct[]
	): Promise<ContractTransaction> {
		ensureSignerExists(this.#signer);
		validateSplitInput(userId, tokenAddress, currentReceivers);

		return this.#driver.split(userId, tokenAddress, formatSplitReceivers(currentReceivers));
	}

	/**
	 * Returns the user's collectable balance.
	 * Collectable balance contains the user's funds that are already split and ready to be collected.
	 * @param  {string} userId user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @returns A `Promise` which resolves to the the collectable balance.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 */
	public async getCollectableBalanceForUser(userId: string, tokenAddress: string): Promise<CollectableBalance> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get collectable balance: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		const collectableBalance = await this.#driver.collectable(userId, tokenAddress);

		return {
			tokenAddress,
			collectableAmount: collectableBalance.toBigInt()
		};
	}

	/**
	 * Returns the user's beams state.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @returns A Promise which resolves to the {@link BeamsState}.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` is not valid.
	 * @throws {@link BeamsErrors.argumentMissingError} if the `userId` is missing.
	 */
	public async beamsState(userId: string, tokenAddress: string): Promise<BeamsState> {
		validateAddress(tokenAddress);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get beams state: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		const { beamsHash, beamsHistoryHash, updateTime, balance, maxEnd } = await this.#driver.beamsState(
			userId,
			tokenAddress
		);

		return {
			beamsHash,
			beamsHistoryHash,
			updateTime,
			balance: balance?.toBigInt(),
			maxEnd
		};
	}

	/**
	 * Returns the user's beams balance at a given timestamp.
	 * Beams balance contains the funds the user can stream to other users.
	 * @param  {string} userId The user ID.
	 * @param  {string} tokenAddress The ERC20 token address.
	 *
	 * It must preserve amounts, so if some amount of tokens is transferred to
	 * an address, then later the same amount must be transferrable from that address.
	 * Tokens which rebase the holders' balances, collect taxes on transfers,
	 * or impose any restrictions on holding or transferring tokens are not supported.
	 * If you use such tokens in the protocol, they can get stuck or lost.
	 * @param  {BeamsReceiverStruct[]} receivers The users's current beams receivers.
	 * @param  {BigNumberish} timestamp The timestamp for which the balance should be calculated. It can't be lower than the timestamp of the last call to `setBeams`.
	 * If it's bigger than `block.timestamp`, then it's a prediction assuming that `setBeams` won't be called before `timestamp`.
	 * @returns A Promise which resolves to the user balance on `timestamp`.
	 * @throws {@link BeamsErrors.argumentMissingError} if any of the required parameters is missing.
	 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` is not valid.
	 * @throws {@link BeamsErrors.argumentError} if `receivers`' count exceeds the max allowed beams receivers.
	 * @throws {@link BeamsErrors.beamsReceiverError} if any of the the `receivers` is not valid.
	 * @throws {@link BeamsErrors.beamsReceiverConfigError} if any of the receivers' configuration is not valid.
	 *
	 */
	public async getBeamsBalanceAt(
		userId: string,
		tokenAddress: string,
		receivers: BeamsReceiverStruct[],
		timestamp: BigNumberish
	): Promise<bigint> {
		validateAddress(tokenAddress);
		validateBeamsReceivers(
			receivers.map((r) => ({
				userId: r.userId.toString(),
				config: Utils.BeamsReceiverConfiguration.fromUint256(BigNumber.from(r.config).toBigInt())
			}))
		);

		if (isNullOrUndefined(userId)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get balance: '${nameOf({ userId })}' is missing.`,
				nameOf({ userId })
			);
		}

		if (isNullOrUndefined(timestamp)) {
			throw BeamsErrors.argumentMissingError(
				`Could not get balance: '${nameOf({ timestamp })}' is missing.`,
				nameOf({ timestamp })
			);
		}

		const beamsBalance = await this.#driver.balanceAt(userId, tokenAddress, receivers, timestamp);

		return beamsBalance.toBigInt();
	}
}

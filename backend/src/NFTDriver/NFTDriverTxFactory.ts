/* eslint-disable no-dupe-class-members */
import type { NFTDriver, BeamsReceiverStruct, SplitsReceiverStruct, UserMetadataStruct } from 'contracts/NFTDriver';
import type { PromiseOrValue } from 'contracts/common';
import type { PopulatedTransaction, BigNumberish, Signer, Overrides } from 'ethers';
import { formatBeamsReceivers, formatSplitReceivers, safeBeamsTx } from '../common/internals';
import { NFTDriver__factory } from '../../contracts/factories';
import { validateClientSigner } from '../common/validators';
import Utils from '../utils';

export interface INFTDriverTxFactory
	extends Pick<
		NFTDriver['populateTransaction'],
		'mint' | 'safeMint' | 'collect' | 'give' | 'setSplits' | 'setBeams' | 'emitUserMetadata'
	> {}

export default class NFTDriverTxFactory implements INFTDriverTxFactory {
	#signer!: Signer;
	#driver!: NFTDriver;
	#driverAddress!: string;

	public get driverAddress(): string {
		return this.#driverAddress;
	}

	public get signer(): Signer {
		return this.#signer;
	}

	/**
	 * Creates a new immutable `NFTDriverTxFactory` instance.
	 *
	 * @param signer The signer that will be used to sign the generated transactions.
	 *
	 * The `singer` must be connected to a provider.
	 *
	 * The supported networks are:
	 * - 'base-goerli': chain ID `84531`
	 * @param customDriverAddress Overrides the `NFTDriver` contract address.
	 * If it's `undefined` (default value), the address will be automatically selected based on the `signer.provider`'s network.
	 * @returns A `Promise` which resolves to the new client instance.
	 * @throws {@link BeamsErrors.initializationError} if the initialization fails.
	 */
	public static async create(signer: Signer, customDriverAddress?: string): Promise<NFTDriverTxFactory> {
		await validateClientSigner(signer, Utils.Network.SUPPORTED_CHAINS);

		const { chainId } = await signer.provider!.getNetwork(); // If the validation passed we know that the signer is connected to a provider.

		const driverAddress = customDriverAddress || Utils.Network.configs[chainId].NFT_DRIVER;

		const client = new NFTDriverTxFactory();
		client.#signer = signer;
		client.#driverAddress = driverAddress;
		client.#driver = NFTDriver__factory.connect(driverAddress, signer);

		return client;
	}

	public async mint(
		to: PromiseOrValue<string>,
		userMetadata: UserMetadataStruct[],
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.mint(to, userMetadata, overrides));
	}

	public async safeMint(
		to: PromiseOrValue<string>,
		userMetadata: UserMetadataStruct[],
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.safeMint(to, userMetadata, overrides));
	}

	public async safeMintWithSalt(
		salt: PromiseOrValue<BigNumberish>,
		to: PromiseOrValue<string>,
		userMetadata: UserMetadataStruct[],
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.safeMintWithSalt(salt, to, userMetadata, overrides));
	}

	public async collect(
		tokenId: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		transferTo: PromiseOrValue<string>,
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.collect(tokenId, erc20, transferTo, overrides));
	}

	public async give(
		tokenId: PromiseOrValue<BigNumberish>,
		receiver: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		amt: PromiseOrValue<BigNumberish>,
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.give(tokenId, receiver, erc20, amt, overrides));
	}

	public async setSplits(
		tokenId: PromiseOrValue<BigNumberish>,
		receivers: SplitsReceiverStruct[],
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(
			await this.#driver.populateTransaction.setSplits(tokenId, formatSplitReceivers(receivers), overrides)
		);
	}

	public async setBeams(
		tokenId: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		currReceivers: BeamsReceiverStruct[],
		balanceDelta: PromiseOrValue<BigNumberish>,
		newReceivers: BeamsReceiverStruct[],
		maxEndHint1: PromiseOrValue<BigNumberish>,
		maxEndHint2: PromiseOrValue<BigNumberish>,
		transferTo: PromiseOrValue<string>,
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		if (!overrides.gasLimit) {
			const gasEstimation = await this.#driver.estimateGas.setBeams(
				tokenId,
				erc20,
				formatBeamsReceivers(currReceivers),
				balanceDelta,
				formatBeamsReceivers(newReceivers),
				maxEndHint1,
				maxEndHint2,
				transferTo,
				overrides
			);

			const gasLimit = Math.ceil(gasEstimation.toNumber() * 1.2);
			// eslint-disable-next-line no-param-reassign
			overrides = { ...overrides, gasLimit };
		}

		return safeBeamsTx(
			await this.#driver.populateTransaction.setBeams(
				tokenId,
				erc20,
				formatBeamsReceivers(currReceivers),
				balanceDelta,
				formatBeamsReceivers(newReceivers),
				maxEndHint1,
				maxEndHint2,
				transferTo,
				overrides
			)
		);
	}

	public async emitUserMetadata(
		tokenId: PromiseOrValue<BigNumberish>,
		userMetadata: UserMetadataStruct[],
		overrides: Overrides & { from?: PromiseOrValue<string> } = {}
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.emitUserMetadata(tokenId, userMetadata, overrides));
	}
}

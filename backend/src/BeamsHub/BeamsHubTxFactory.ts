/* eslint-disable no-dupe-class-members */
import type { Provider } from '@ethersproject/providers';
import type { BeamsHistoryStruct, BeamsHub, SplitsReceiverStruct } from 'contracts/BeamsHub';
import type { PromiseOrValue } from 'contracts/common';
import type { PopulatedTransaction, BigNumberish, BytesLike } from 'ethers';
import { safeBeamsTx } from '../common/internals';
import { BeamsHub__factory } from '../../contracts/factories';
import { validateClientProvider } from '../common/validators';
import Utils from '../utils';

interface IBeamsHubTxFactory extends Pick<BeamsHub['populateTransaction'], 'receiveBeams' | 'squeezeBeams' | 'split'> {}

export default class BeamsHubTxFactory implements IBeamsHubTxFactory {
	#driver!: BeamsHub;
	#driverAddress!: string;

	public get driverAddress(): string {
		return this.#driverAddress;
	}

	public static async create(provider: Provider, customDriverAddress?: string): Promise<BeamsHubTxFactory> {
		await validateClientProvider(provider, Utils.Network.SUPPORTED_CHAINS);

		const network = await provider.getNetwork();
		const driverAddress = customDriverAddress ?? Utils.Network.configs[network.chainId].ADDRESS_DRIVER;

		const client = new BeamsHubTxFactory();

		client.#driverAddress = driverAddress;

		client.#driver = BeamsHub__factory.connect(driverAddress, provider);

		return client;
	}

	async receiveBeams(
		userId: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		maxCycles: PromiseOrValue<BigNumberish>
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.receiveBeams(userId, erc20, maxCycles));
	}

	async squeezeBeams(
		userId: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		senderId: PromiseOrValue<BigNumberish>,
		historyHash: PromiseOrValue<BytesLike>,
		beamsHistory: BeamsHistoryStruct[]
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(
			await this.#driver.populateTransaction.squeezeBeams(userId, erc20, senderId, historyHash, beamsHistory)
		);
	}

	async split(
		userId: PromiseOrValue<BigNumberish>,
		erc20: PromiseOrValue<string>,
		currReceivers: SplitsReceiverStruct[]
	): Promise<PopulatedTransaction> {
		return safeBeamsTx(await this.#driver.populateTransaction.split(userId, erc20, currReceivers));
	}
}

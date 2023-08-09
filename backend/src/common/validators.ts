import type { Provider } from '@ethersproject/providers';
import type { BigNumberish, Signer } from 'ethers';
import { ethers } from 'ethers';
import { BeamsErrors } from './BeamsError';
import { isNullOrUndefined, nameOf } from './internals';
import type { BeamsReceiverConfig, SplitsReceiverStruct, BeamsHistoryStruct, UserMetadata } from './types';

const MAX_BEAMS_RECEIVERS = 100;
const MAX_SPLITS_RECEIVERS = 200;

/** @internal */
export const validateAddress = (address: string) => {
	if (!ethers.utils.isAddress(address)) {
		throw BeamsErrors.addressError(`Address validation failed: address '${address}' is not valid.`, address);
	}
};

/** @internal */
export const validateBeamsReceiverConfig = (beamsReceiverConfig: BeamsReceiverConfig): void => {
	if (!beamsReceiverConfig) {
		throw BeamsErrors.argumentMissingError(
			`Beams receiver config validation failed: '${nameOf({ beamsReceiverConfig })}' is missing.`,
			nameOf({ beamsReceiverConfig })
		);
	}

	const { beamId, start, duration, amountPerSec } = beamsReceiverConfig;

	if (isNullOrUndefined(beamId) || beamId < 0) {
		throw BeamsErrors.beamsReceiverConfigError(
			`Beams receiver config validation failed: '${nameOf({ beamId })}' must be greater than or equal to 0`,
			nameOf({ start }),
			start
		);
	}

	if (isNullOrUndefined(start) || start < 0) {
		throw BeamsErrors.beamsReceiverConfigError(
			`Beams receiver config validation failed: '${nameOf({ start })}' must be greater than or equal to 0`,
			nameOf({ start }),
			start
		);
	}

	if (isNullOrUndefined(duration) || duration < 0) {
		throw BeamsErrors.beamsReceiverConfigError(
			`Beams receiver config validation failed: '${nameOf({ duration })}' must be greater than or equal to 0`,
			nameOf({ duration }),
			duration
		);
	}

	if (isNullOrUndefined(amountPerSec) || amountPerSec <= 0) {
		throw BeamsErrors.beamsReceiverConfigError(
			`Beams receiver config validation failed: '${nameOf({ amountPerSec })}' must be greater than 0.`,
			nameOf({ amountPerSec }),
			amountPerSec
		);
	}
};

/** @internal */
export const validateBeamsReceivers = (receivers: { userId: string; config: BeamsReceiverConfig }[]) => {
	if (!receivers) {
		throw BeamsErrors.argumentMissingError(
			`Beams receivers validation failed: '${nameOf({ receivers })}' is missing.`,
			nameOf({ receivers })
		);
	}

	if (receivers.length > MAX_BEAMS_RECEIVERS) {
		throw BeamsErrors.argumentError(
			`Beams receivers validation failed: max number of beams receivers exceeded. Max allowed ${MAX_BEAMS_RECEIVERS} but were ${receivers.length}.`,
			nameOf({ receivers }),
			receivers
		);
	}

	if (receivers.length) {
		receivers.forEach((receiver) => {
			const { userId, config } = receiver;

			if (isNullOrUndefined(userId)) {
				throw BeamsErrors.beamsReceiverError(
					`Beams receivers validation failed: '${nameOf({ userId })}' is missing.`,
					nameOf({ userId }),
					userId
				);
			}
			if (isNullOrUndefined(config)) {
				throw BeamsErrors.beamsReceiverError(
					`Beams receivers validation failed: '${nameOf({ config })}' is missing.`,
					nameOf({ config }),
					config
				);
			}

			validateBeamsReceiverConfig(config);
		});
	}
};

/** @internal */
export const validateSplitsReceivers = (receivers: SplitsReceiverStruct[]) => {
	if (!receivers) {
		throw BeamsErrors.argumentMissingError(
			`Splits receivers validation failed: '${nameOf({ receivers })}' is missing.`,
			nameOf({ receivers })
		);
	}

	if (receivers.length > MAX_SPLITS_RECEIVERS) {
		throw BeamsErrors.argumentError(
			`Splits receivers validation failed: max number of beams receivers exceeded. Max allowed ${MAX_SPLITS_RECEIVERS} but were ${receivers.length}.`,
			nameOf({ receivers }),
			receivers
		);
	}

	if (receivers.length) {
		receivers.forEach((receiver) => {
			const { userId, weight } = receiver;

			if (!userId) {
				throw BeamsErrors.splitsReceiverError(
					`Splits receivers validation failed: '${nameOf({ userId })}' is missing.`,
					nameOf({ userId }),
					userId
				);
			}

			if (isNullOrUndefined(weight)) {
				throw BeamsErrors.splitsReceiverError(
					`Splits receivers validation failed: '${nameOf({ weight })}' is missing.`,
					nameOf({ weight }),
					weight
				);
			}

			if (weight <= 0) {
				throw BeamsErrors.splitsReceiverError(
					`Splits receiver config validation failed: : '${nameOf({ weight })}' must be greater than 0.`,
					nameOf({ weight }),
					weight
				);
			}
		});
	}
};

/** @internal */
export const validateClientProvider = async (provider: Provider, supportedChains: readonly number[]) => {
	if (!provider) {
		throw BeamsErrors.initializationError(`The provider is missing.`);
	}

	const network = await provider.getNetwork();
	if (!supportedChains.includes(network?.chainId)) {
		throw BeamsErrors.initializationError(
			`The provider is connected to an unsupported network with chain ID '${network?.chainId}' ('${network?.name}'). Supported chain IDs are: ${supportedChains}.`
		);
	}
};

/** @internal */
export const validateClientSigner = async (signer: Signer, supportedChains: readonly number[]) => {
	if (!signer) {
		throw BeamsErrors.initializationError(`The singer is missing.`);
	}

	const address = await signer.getAddress();
	if (!ethers.utils.isAddress(address)) {
		throw BeamsErrors.initializationError(`Signer's address ('${address}') is not valid.`);
	}

	const { provider } = signer;
	if (!provider) {
		throw BeamsErrors.initializationError(`The signer has no provider.`);
	}

	const network = await provider.getNetwork();
	if (!supportedChains.includes(network?.chainId)) {
		throw BeamsErrors.initializationError(
			`The signer's provider is connected to an unsupported network with chain ID '${network?.chainId}' ('${network?.name}'). Supported chain IDs are: ${supportedChains}.`
		);
	}
};

/** @internal */
export const validateSetBeamsInput = (
	tokenAddress: string,
	currentReceivers: {
		userId: string;
		config: BeamsReceiverConfig;
	}[],
	newReceivers: {
		userId: string;
		config: BeamsReceiverConfig;
	}[],
	transferToAddress: string,
	balanceDelta: BigNumberish
) => {
	validateAddress(tokenAddress);
	validateAddress(transferToAddress);
	validateBeamsReceivers(newReceivers);
	validateBeamsReceivers(currentReceivers);
	if (isNullOrUndefined(balanceDelta)) {
		throw BeamsErrors.argumentMissingError(
			`Could not set beams: '${nameOf({ balanceDelta })}' is missing.`,
			nameOf({ balanceDelta })
		);
	}
};

/** @internal */
export const validateEmitUserMetadataInput = (metadata: UserMetadata[]) => {
	if (!metadata) {
		throw BeamsErrors.argumentError(`Invalid user metadata: '${nameOf({ metadata })}' is missing.`);
	}

	metadata.forEach((meta) => {
		const { key, value } = meta;

		if (!key) {
			throw BeamsErrors.argumentError(`Invalid user metadata: '${nameOf({ key })}' is missing.`);
		}

		if (!value) {
			throw BeamsErrors.argumentError(`Invalid user metadata: '${nameOf({ value })}' is missing.`);
		}
	});
};

/** @internal */
export const validateReceiveBeamsInput = (userId: string, tokenAddress: string, maxCycles: BigNumberish) => {
	validateAddress(tokenAddress);

	if (isNullOrUndefined(userId)) {
		throw BeamsErrors.argumentMissingError(
			`Could not receive beams: '${nameOf({ userId })}' is missing.`,
			nameOf({ userId })
		);
	}

	if (!maxCycles || maxCycles < 0) {
		throw BeamsErrors.argumentError(
			`Could not receive beams: '${nameOf({ maxCycles })}' must be greater than 0.`,
			nameOf({ maxCycles }),
			maxCycles
		);
	}
};

/** @internal */
export const validateSplitInput = (
	userId: BigNumberish,
	tokenAddress: string,
	currentReceivers: SplitsReceiverStruct[]
) => {
	validateAddress(tokenAddress);
	validateSplitsReceivers(currentReceivers);

	if (isNullOrUndefined(userId)) {
		throw BeamsErrors.argumentMissingError(`Could not split: '${nameOf({ userId })}' is missing.`, nameOf({ userId }));
	}
};

/** @internal */
export const validateCollectInput = (tokenAddress: string, transferToAddress: string) => {
	validateAddress(tokenAddress);
	validateAddress(transferToAddress);
};

/** @internal */
export const validateSqueezeBeamsInput = (
	userId: string,
	tokenAddress: string,
	senderId: BigNumberish,
	historyHash: string,
	beamsHistory: BeamsHistoryStruct[]
) => {
	validateAddress(tokenAddress);

	if (!userId) {
		throw BeamsErrors.argumentError(`Invalid input for squeezing: '${nameOf({ userId })}' is missing.`);
	}

	if (!senderId) {
		throw BeamsErrors.argumentError(`Invalid input for squeezing: '${nameOf({ senderId })}' is missing.`);
	}

	if (!historyHash) {
		throw BeamsErrors.argumentError(`Invalid input for squeezing: '${nameOf({ historyHash })}' is missing.`);
	}

	if (!beamsHistory) {
		throw BeamsErrors.argumentError(`Invalid input for squeezing: '${nameOf({ beamsHistory })}' is missing.`);
	}
};

/* eslint-disable max-classes-per-file */

import type { ContractReceipt } from 'ethers';

export enum BeamsErrorCode {
	MISSING_SIGNER = 'MISSING_SIGNER',
	INVALID_ADDRESS = 'INVALID_ADDRESS',
	INVALID_ARGUMENT = 'INVALID_ARGUMENT',
	MISSING_ARGUMENT = 'MISSING_ARGUMENT',
	TX_EVENT_NOT_FOUND = 'TX_EVENT_NOT_FOUND',
	UNSUPPORTED_NETWORK = 'UNSUPPORTED_NETWORK',
	SUBGRAPH_QUERY_ERROR = 'SUBGRAPH_QUERY_ERROR',
	INVALID_BEAMS_RECEIVER = 'INVALID_BEAMS_RECEIVER',
	INITIALIZATION_FAILURE = 'INITIALIZATION_FAILURE',
	INVALID_SPLITS_RECEIVER = 'INVALID_SPLITS_RECEIVER',
	INVALID_BEAMS_RECEIVER_CONFIG = 'INVALID_BEAMS_RECEIVER_CONFIG'
}

export class BeamsError extends Error {
	public readonly context?: unknown;
	public readonly code: BeamsErrorCode;

	constructor(code: BeamsErrorCode, message: string, context?: unknown) {
		super(message);

		this.code = code;
		this.context = context;
	}
}

export class BeamsErrors {
	static initializationError = (message: string) => new BeamsError(BeamsErrorCode.INITIALIZATION_FAILURE, message);

	static addressError = (message: string, address: string) =>
		new BeamsError(BeamsErrorCode.INVALID_ADDRESS, message, {
			invalidAddress: address
		});

	static txEventNotFound = (message: string, eventName: string, txReceipt: ContractReceipt) =>
		new BeamsError(BeamsErrorCode.TX_EVENT_NOT_FOUND, message, {
			eventName,
			txReceipt
		});

	static signerMissingError = (
		message: string = 'Tried to perform an operation that requires a signer but a signer was not found.'
	) => new BeamsError(BeamsErrorCode.MISSING_SIGNER, message);

	static argumentMissingError = (message: string, argName: string) =>
		new BeamsError(BeamsErrorCode.MISSING_ARGUMENT, message, {
			missingArgumentName: argName
		});

	static unsupportedNetworkError = (message: string, chainId: number) =>
		new BeamsError(BeamsErrorCode.UNSUPPORTED_NETWORK, message, {
			unsupportedChainId: chainId
		});

	static argumentError = (message: string, argName?: string, argValue?: unknown) =>
		new BeamsError(
			BeamsErrorCode.INVALID_ARGUMENT,
			message,
			argName
				? {
						invalidArgument: { name: argName, value: argValue }
				  }
				: undefined
		);

	static splitsReceiverError = (message: string, invalidPropertyName: string, invalidPropertyValue: unknown) =>
		new BeamsError(BeamsErrorCode.INVALID_SPLITS_RECEIVER, message, {
			invalidProperty: {
				name: invalidPropertyName,
				value: invalidPropertyValue
			}
		});

	static beamsReceiverError = (message: string, invalidPropertyName: string, invalidPropertyValue: unknown) =>
		new BeamsError(BeamsErrorCode.INVALID_BEAMS_RECEIVER, message, {
			invalidProperty: {
				name: invalidPropertyName,
				value: invalidPropertyValue
			}
		});

	static beamsReceiverConfigError = (message: string, invalidPropertyName: string, invalidPropertyValue: unknown) =>
		new BeamsError(BeamsErrorCode.INVALID_BEAMS_RECEIVER_CONFIG, message, {
			invalidProperty: {
				name: invalidPropertyName,
				value: invalidPropertyValue
			}
		});

	static subgraphQueryError = (message: string) => new BeamsError(BeamsErrorCode.SUBGRAPH_QUERY_ERROR, message);
}

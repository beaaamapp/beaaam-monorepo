import type { BigNumberish, BytesLike } from 'ethers';
import { BigNumber, ethers } from 'ethers';
import { BeamsErrors } from './common/BeamsError';
import type { NetworkConfig, CycleInfo, BeamsReceiverConfig, UserMetadataStruct } from './common/types';
import { validateAddress, validateBeamsReceiverConfig } from './common/validators';

namespace Utils {
	export namespace Metadata {
		/**
		 * Converts a `string` to a `BytesLike` representation.
		 *
		 * @param key - The `string` to be converted.
		 * @returns The converted `BytesLike` representation of the `string`.
		 */
		export const keyFromString = (key: string): BytesLike => ethers.utils.formatBytes32String(key);

		/**
		 * Converts a `string` to a hex-encoded `BytesLike` representation.
		 *
		 * @param value - The `string` to be converted.
		 * @returns The hex-encoded `BytesLike` representation of the `string`.
		 */
		export const valueFromString = (value: string): BytesLike => ethers.utils.hexlify(ethers.utils.toUtf8Bytes(value));

		/**
		 * Creates an object containing the `BytesLike` representations of the provided key and value `string`s.
		 *
		 * @param key - The `string` to be converted to a `BytesLike` key.
		 * @param value - The `string` to be converted to a `BytesLike` value.
		 * @returns An object containing the `BytesLike` representations of the key and value `string`s.
		 */
		export const createFromStrings = (
			key: string,
			value: string
		): {
			key: BytesLike;
			value: BytesLike;
		} => ({
			key: keyFromString(key),
			value: valueFromString(value)
		});

		/**
		 * Parses the `UserMetadataStruct` and converts the key and value from `BytesLike` to `string` format.
		 *
		 * @param userMetadata - The `UserMetadataStruct` containing the key and value in `BytesLike` format.
		 * @returns An `object` containing the key and value as `string`s.
		 */
		export const convertMetadataBytesToString = (userMetadata: UserMetadataStruct): { key: string; value: string } => {
			if (!ethers.utils.isBytesLike(userMetadata?.key) || !ethers.utils.isBytesLike(userMetadata?.value)) {
				throw BeamsErrors.argumentError(
					`Invalid key-value user metadata pair: key or value is not a valid BytesLike object.`
				);
			}

			return {
				key: ethers.utils.parseBytes32String(userMetadata.key),
				value: ethers.utils.toUtf8String(userMetadata.value)
			};
		};
	}

	
	export namespace Network {
		export const configs: Record<number, NetworkConfig> = {
			// base-goerl
			84531 : {
				CHAIN:  "base-goerli",
				DEPLOYMENT_TIME:  "2023-08-05T17:25:38+00:00",
				COMMIT_HASH: 'd6711ef9c9eee8fd9c6e6c19ba7609e64f204663',
				WALLET: '0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E',
				WALLET_NONCE: '4',
				DEPLOYER: '0x16de95d9199Fceb3546565909eB52a4726B14311',
				BEAMS_HUB: '0x13A44B35554AbD701158c9877510Eee38870f85E',
				BEAMS_HUB_CYCLE_SECONDS: '604800',
				BEAMS_HUB_LOGIC: '0x3BbF4dA7457253cB05D517340cC436f0aAfED9Db',
				BEAMS_HUB_ADMIN: '0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E',
				CALLER: '0x091fb6A649ee93812458cFD269e7Bf6DE995039b',
				ADDRESS_DRIVER: '0xeC93173931E6545b017Cda824Deca8445045f53e',
				ADDRESS_DRIVER_LOGIC: '0x7dC2e157E123a1a3dEf9c354b3a4B4dE2d7b5755',
				ADDRESS_DRIVER_ADMIN: '0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E',
				ADDRESS_DRIVER_ID: '0',
				NFT_DRIVER: '0x5AE787F9C326E05cBe7E0f652eEDa79182928675',
				NFT_DRIVER_LOGIC: '0x2BA2C0f36aF75e614D5733A8106143C441bDa9ea',
				NFT_DRIVER_ADMIN: '0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E',
				NFT_DRIVER_ID: '1',
				IMMUTABLE_SPLITS_DRIVER: '0x69aa68Bb2B1144B27327B8Eb6fBAd47E272c0FBF',
				IMMUTABLE_SPLITS_DRIVER_LOGIC: '0x12a9a3cA1B696f3BEcEf0E77bCd527557af24EA3',
				IMMUTABLE_SPLITS_DRIVER_ADMIN: '0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E',
				IMMUTABLE_SPLITS_DRIVER_ID: '2',
				SUBGRAPH_URL: 'https://api.studio.thegraph.com/query/50446/beam/v0.0.6'
			},

			420: {
				CHAIN:                       "optimism-goerli",
				 DEPLOYMENT_TIME:              "2023-08-11T18:59:59+00:00",
				 COMMIT_HASH:                  "04a422c4970cc132f8084635743b9d39861e4c3d",
				 WALLET:                       "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 WALLET_NONCE:                 "7",
				 DEPLOYER:                     "0xa09861C51676CF0fB34b22F8e0199A507D8a26EA",
				 BEAMS_HUB:                     "0x00FA9D90FF061EF57214524FDf1744B5670dC214",
				 BEAMS_HUB_CYCLE_SECONDS:       "604800",
				 BEAMS_HUB_LOGIC:               "0x0656c5FDc1f5DdDc9e136F2727467B2d396AFf26",
				 BEAMS_HUB_ADMIN:               "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 CALLER:                       "0x8628E24C4011d585DD2534CFBE97103a460dFec3",
				 ADDRESS_DRIVER:                "0xB9C9e6A54848A278a1601428Ae66ec693c6f4F29",
				 ADDRESS_DRIVER_LOGIC:          "0x996f34972231111313Aa93785C57D9a82A9C150B",
				 ADDRESS_DRIVER_ADMIN:          "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 ADDRESS_DRIVER_ID:             "0",
				 NFT_DRIVER:                    "0xb0BAF324630e79CD7351ADc81B40b60Ca70792b7",
				 NFT_DRIVER_LOGIC:              "0x57f33756637f9BCc67794fd6d913971Ce69a451d",
				 NFT_DRIVER_ADMIN:              "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 NFT_DRIVER_ID:                 "1",
				 IMMUTABLE_SPLITS_DRIVER:        "0xC3688797ebBe9f39E82Ee4A17CDec96d068A7b57",
				 IMMUTABLE_SPLITS_DRIVER_LOGIC:  "0x0E81BC2B65FA49920a607925E8bdC52E4275bcB8",
				 IMMUTABLE_SPLITS_DRIVER_ADMIN:  "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 IMMUTABLE_SPLITS_DRIVER_ID:     "2",
				 SUBGRAPH_URL: 'https://api.studio.thegraph.com/query/50446/beam-optest/v0.0.6'
				 
			 },

			 999:{
				CHAIN:                       "zora",
				 DEPLOYMENT_TIME:              "2023-08-11T18:40:43+00:00",
				 COMMIT_HASH:                  "04a422c4970cc132f8084635743b9d39861e4c3d",
				 WALLET:                       "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 WALLET_NONCE:                 "3",
				 DEPLOYER:                     "0x804BCb3B87F93Ec42B672cda3f88A1978d6e884F",
				 BEAMS_HUB:                     "0x09d380C508b22647A37Bc47f87721D3cA2448653",
				 BEAMS_HUB_CYCLE_SECONDS:       "604800",
				 BEAMS_HUB_LOGIC:               "0x7E806888a251CEcfb99c7c44ecfAa434C1E71672",
				 BEAMS_HUB_ADMIN:               "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 CALLER:                       "0x25b8560d6d9BA0826969EC84721cEd7C391b67dA",
				 ADDRESS_DRIVER:                "0x1672984Cc98dcb60dc2352A259D29463Dc0043EF",
				 ADDRESS_DRIVER_LOGIC:          "0x59844bA02DaF13d4856b434EEA64b2ACC5d644b9",
				 ADDRESS_DRIVER_ADMIN:          "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 ADDRESS_DRIVER_ID:             "0",
				 NFT_DRIVER:                    "0x0779267e5aF92C45e2ecd3BD7dA3652690497170",
				 NFT_DRIVER_LOGIC:              "0xE03d6b0683B02998136e5971c9b8B1e3F1297959",
				 NFT_DRIVER_ADMIN:              "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 NFT_DRIVER_ID:                 "1",
				 IMMUTABLE_SPLITS_DRIVER:        "0x0001de2940E1220be871cf9B1044016A83838Af7",
				 IMMUTABLE_SPLITS_DRIVER_LOGIC:  "0x08f0C62A7829327DD54Af5dA8Aa1daCBc767A02A",
				 IMMUTABLE_SPLITS_DRIVER_ADMIN:  "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				 IMMUTABLE_SPLITS_DRIVER_ID:     "2",
				 SUBGRAPH_URL: ''
			 },

			 919:{
				CHAIN:"mode",
				DEPLOYMENT_TIME: "2023-08-11T18:32:02+00:00",
				COMMIT_HASH: "04a422c4970cc132f8084635743b9d39861e4c3d",
				WALLET: "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				WALLET_NONCE: "3",
				DEPLOYER: "0x804BCb3B87F93Ec42B672cda3f88A1978d6e884F",
				BEAMS_HUB: "0x09d380C508b22647A37Bc47f87721D3cA2448653",
				BEAMS_HUB_CYCLE_SECONDS: "604800",
				BEAMS_HUB_LOGIC: "0x7E806888a251CEcfb99c7c44ecfAa434C1E71672",
				BEAMS_HUB_ADMIN: "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				CALLER: "0x25b8560d6d9BA0826969EC84721cEd7C391b67dA",
				ADDRESS_DRIVER: "0x1672984Cc98dcb60dc2352A259D29463Dc0043EF",
				ADDRESS_DRIVER_LOGIC: "0x59844bA02DaF13d4856b434EEA64b2ACC5d644b9",
				ADDRESS_DRIVER_ADMIN: "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				ADDRESS_DRIVER_ID: "0",
				NFT_DRIVER: "0x0779267e5aF92C45e2ecd3BD7dA3652690497170",
				NFT_DRIVER_LOGIC: "0xE03d6b0683B02998136e5971c9b8B1e3F1297959",
				NFT_DRIVER_ADMIN: "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				NFT_DRIVER_ID: "1",
				IMMUTABLE_SPLITS_DRIVER: "0x0001de2940E1220be871cf9B1044016A83838Af7",
				IMMUTABLE_SPLITS_DRIVER_LOGIC: "0x08f0C62A7829327DD54Af5dA8Aa1daCBc767A02A",
				IMMUTABLE_SPLITS_DRIVER_ADMIN: "0x840C1b6ce85bBFEbcFAd737514c0097B078a7E7E",
				IMMUTABLE_SPLITS_DRIVER_ID: "2",
				SUBGRAPH_URL: ''
			}
		};

		export const SUPPORTED_CHAINS: readonly number[] = Object.freeze(
			Object.keys(configs).map((chainId) => parseInt(chainId, 10))
		);

		export const isSupportedChain = (chainId: number) => {
			if (SUPPORTED_CHAINS.includes(chainId)) {
				return true;
			}

			return false;
		};
	}
	export namespace Cycle {
		const getUnixTime = (date: Date): number => date.getTime() / 1000;

		export const getInfo = (chainId: number): CycleInfo => {
			if (!Network.isSupportedChain(chainId)) {
				throw BeamsErrors.unsupportedNetworkError(
					`Could not get cycle info: chain ID '${chainId}' is not supported. Supported chain IDs are: ${Network.SUPPORTED_CHAINS.toString()}.`,
					chainId
				);
			}

			const cycleDurationSecs = BigInt(Network.configs[chainId].BEAMS_HUB_CYCLE_SECONDS);

			const currentCycleSecs = BigInt(Math.floor(getUnixTime(new Date()))) % cycleDurationSecs;

			const currentCycleStartDate = new Date(new Date().getTime() - Number(currentCycleSecs) * 1000);

			const nextCycleStartDate = new Date(currentCycleStartDate.getTime() + Number(cycleDurationSecs * BigInt(1000)));

			return {
				cycleDurationSecs,
				currentCycleSecs,
				currentCycleStartDate,
				nextCycleStartDate
			};
		};
	}

	export namespace Asset {
		/**
		 * Returns the ERC20 token address for the given asset.
		 * @param  {BigNumberish} assetId The asset ID.
		 * @returns The ERC20 token address.
		 */
		export const getAddressFromId = (assetId: BigNumberish): string =>
			ethers.utils.getAddress(BigNumber.from(assetId).toHexString());

		/**
		 * Returns the asset ID for the given ERC20 token.
		 * @param  {string} tokenAddress The ERC20 token address.
		 * @returns The asset ID.
		 * @throws {@link BeamsErrors.addressError} if the `tokenAddress` address is not valid.
		 */
		export const getIdFromAddress = (tokenAddress: string): bigint => {
			validateAddress(tokenAddress);

			return BigNumber.from(ethers.utils.getAddress(tokenAddress)).toBigInt();
		};
	}

	export namespace BeamsReceiverConfiguration {
		/**
		 * Converts a beams receiver configuration object to a `uint256`.
		 * @param  {BeamsReceiverConfigDto} beamsReceiverConfig The beams receiver configuration object.
		 * @returns The beams receiver configuration as a `uint256`.
		 * @throws {@link BeamsErrors.argumentMissingError} if the `beamsReceiverConfig` is missing.
		 * @throws {@link BeamsErrors.beamsReceiverConfigError} if the `beamsReceiverConfig` is not valid.
		 */
		export const toUint256 = (beamsReceiverConfig: BeamsReceiverConfig): bigint => {
			validateBeamsReceiverConfig(beamsReceiverConfig);

			const { beamId, start, duration, amountPerSec } = beamsReceiverConfig;

			let config = BigNumber.from(beamId);
			config = config.shl(160);
			config = config.or(amountPerSec);
			config = config.shl(32);
			config = config.or(start);
			config = config.shl(32);
			config = config.or(duration);

			return config.toBigInt();
		};

		/**
		 * Converts a `uint256` that represent a beams receiver configuration to an object.
		 * @param  {BigNumberish} beamsReceiverConfig The beams receiver configuration as`uint256`.
		 * @returns The beams receiver configuration object.
		 * @throws {@link BeamsErrors.argumentMissingError} if the `beamsReceiverConfig` is missing.
		 * @throws {@link BeamsErrors.argumentError} if the `beamsReceiverConfig` is not valid.
		 */
		export const fromUint256 = (beamsReceiverConfig: BigNumberish): BeamsReceiverConfig => {
			const configAsBn = BigNumber.from(beamsReceiverConfig);

			const beamId = configAsBn.shr(160 + 32 + 32);
			const amountPerSec = configAsBn.shr(32 + 32).and(BigNumber.from(1).shl(160).sub(1));
			const start = configAsBn.shr(32).and(BigNumber.from(1).shl(32).sub(1));
			const duration = configAsBn.and(BigNumber.from(1).shl(32).sub(1));

			const config = {
				beamId: beamId.toBigInt(),
				amountPerSec: amountPerSec.toBigInt(),
				duration: duration.toBigInt(),
				start: start.toBigInt()
			};

			validateBeamsReceiverConfig(config);

			return config;
		};
	}
}

export default Utils;

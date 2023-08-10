import wallet from '$lib/stores/wallet/wallet.store';
import assert from '$lib/utils/assert';
import {
  AddressDriverClient,
  AddressDriverTxFactory,
  CallerClient,
  BeamsHubClient,
  BeamsSubgraphClient,
  Utils,
  type NetworkConfig,
} from 'beaaams-backend';
import { get } from 'svelte/store';
import isTest from './is-test';


/**
 * Get an initialized Beams Subgraph client.
 * @returns An initialized Beams Subgraph client.
 */
export function getSubgraphClient() {
  const { network } = get(wallet);

  return BeamsSubgraphClient.create(network.chainId, getNetworkConfig().SUBGRAPH_URL);
}

/**
 * Get an initialized Address Driver client.
 * @returns An initialized Address Driver client.
 */
export function getAddressDriverClient(withSigner = get(wallet).signer) {
  const { provider } = get(wallet);

  const addressDriverAddress = getNetworkConfig().ADDRESS_DRIVER;

  return AddressDriverClient.create(provider, withSigner, addressDriverAddress);
}

/**
 * Get an initialized Address Driver transaction factory.
 * @returns An initialized Address Driver transaction factory.
 */
export function getAddressDriverTxFactory() {
  const { signer } = get(wallet);
  assert(signer);

  const addressDriverAddress = getNetworkConfig().ADDRESS_DRIVER;

  return AddressDriverTxFactory.create(signer, addressDriverAddress);
}

/**
 * Get an initialized Beams Hub client.
 * @returns An initialized Beams Hub client.
 */
export function getBeamsHubClient() {
  const { provider, signer } = get(wallet);

  const beamsHubAddress = getNetworkConfig().BEAMS_HUB;

  return BeamsHubClient.create(provider, signer, beamsHubAddress);
}

/**
 * Get an initialized Caller client.
 * @returns An initialized Caller client.
 */
export function getCallerClient() {
  const { provider, signer, connected } = get(wallet);
  assert(connected, 'Wallet must be connected to create a CallerClient');

  return CallerClient.create(provider, signer, getNetworkConfig().CALLER);
}

/**
 * NetworkConfig object that is aware of being ran in an E2E-test environment, so that
 * clients are initialized with addresses matching local testnet deployments. See `README`'s
 * E2E test section.
 */
export const networkConfigs: { [chainId: number]: NetworkConfig } = isTest()
  ? {
    84531: {
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
				SUBGRAPH_URL: 'https://api.studio.thegraph.com/query/50446/beam/v0.0.5'
      },
    }
  : {
      ...Utils.Network.configs,
    };

/**
 * Get the networkConfig for the current network.
 * @returns The networkConfig for the current network.
 */
export function getNetworkConfig() {
  const { network } = get(wallet);

  return networkConfigs[network.chainId];
}

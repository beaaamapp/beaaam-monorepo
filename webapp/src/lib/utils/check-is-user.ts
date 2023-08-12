import wallet from '$lib/stores/wallet/wallet.store';
import { get } from 'svelte/store';

/**
 * Check if the currently logged-in user's AddressDriver beamsUserId matches
 * a particular beamsUserId.
 * @param beamsUserId The beamsUserId to match against.
 * @returns True if matches, false otherwise.
 */
export default function (beamsUserId: string): boolean {
  const { beamsUserId: currentBeamsUserId } = get(wallet);

  return beamsUserId === currentBeamsUserId;
}

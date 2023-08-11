import wallet from '$lib/stores/wallet/wallet.store';
import { getSubgraphClient } from '$lib/utils/get-beams-clients';
import { get } from 'svelte/store';
import assert from '$lib/utils/assert';

export default async function (senderUserIds: string[], tokenAddress: string) {
  const subgraphClient = getSubgraphClient();

  const { beamsUserId: ownUserId } = get(wallet);
  assert(ownUserId);

  return await Promise.all(
    senderUserIds.map((senderUserId) =>
      subgraphClient.getArgsForSqueezingAllBeams(ownUserId, senderUserId, tokenAddress),
    ),
  );
}

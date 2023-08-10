import { getSubgraphClient } from '$lib/utils/get-beams-clients';
import { Utils } from 'beaaams-backend';

export default async function relevantTokens(
  forBalance: 'receivable' | 'splittable',
  userId: string,
) {
  const subgraph = getSubgraphClient();

  let assetIds: string[];

  if (forBalance === 'receivable') {
    assetIds = (await subgraph.getBeamsReceiverSeenEventsByReceiverId(userId)).map((e) =>
      Utils.Asset.getAddressFromId(e.beamsSetEvent.assetId),
    );
  } else {
    const events = await Promise.all([
      subgraph.getGivenEventsByReceiverUserId(userId),
      subgraph.getSplitEventsByReceiverUserId(userId),
    ]);

    assetIds = events.flat().map((e) => Utils.Asset.getAddressFromId(e.assetId));
  }

  return new Set(assetIds);
}

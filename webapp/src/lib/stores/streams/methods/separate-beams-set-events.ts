import { Utils, type BeamsSetEvent } from 'beaaams-backend';
import sortBeamsSetEvents from './sort-beams-set-events';

/**
 * Take an array of beamsSetEvents, and group them by their asset's token address.
 * @param beamsSetEvents The array of events to group by token address.
 * @returns An object with keys corresponding to token addresses, and values being
 * relevant beamsSetEvents.
 */
export default function seperateBeamsSetEvents<T extends BeamsSetEvent>(
  beamsSetEvents: T[],
): {
  [tokenAddress: string]: T[];
} {
  const sorted = sortBeamsSetEvents(beamsSetEvents);

  const result = sorted.reduce<{ [tokenAddress: string]: T[] }>((acc, beamsSetEvent) => {
    const { assetId } = beamsSetEvent;
    const tokenAddress = Utils.Asset.getAddressFromId(assetId);

    if (acc[tokenAddress]) {
      acc[tokenAddress].push(beamsSetEvent);
    } else {
      acc[tokenAddress] = [beamsSetEvent];
    }

    return acc;
  }, {});

  return result;
}

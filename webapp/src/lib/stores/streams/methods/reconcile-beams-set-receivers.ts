import deduplicateArray from '$lib/utils/deduplicate-array';
import type { BeamsSetEvent } from 'beaaams-backend';
import sortBeamsSetEvents from './sort-beams-set-events';

interface BeamsReceiverSeenEvent {
  id: string;
  receiverUserId: string;
  config: bigint;
}

export type BeamsSetEventWithFullReceivers = {
  currentReceivers: BeamsReceiverSeenEvent[];
} & BeamsSetEvent;

type ReceiversHash = string;

/**
 * Currently, `beamsSetEvents` as queried from our subgraph don't include the historic state of receivers
 * at the time of update. This function takes all historically seen beams receivers, and enriches a set of
 * `beamsSetEvents` with a new `currentReceivers` key that includes the full state of receivers at the time
 * of update.
 *
 * 
 *
 * @param beamsSetEvents The beams set events to enrich.
 * @returns The same beams set events, with an additional `currentReceivers` key, containing all receivers
 * that were configured on-chain at the time of update.
 */
export function reconcileBeamsSetReceivers(
  beamsSetEvents: BeamsSetEvent[],
): BeamsSetEventWithFullReceivers[] {
  const sortedBeamsSetEvents = sortBeamsSetEvents(beamsSetEvents);

  const receiversHashes = sortedBeamsSetEvents.reduce<ReceiversHash[]>((acc, beamsSetEvent) => {
    const { receiversHash } = beamsSetEvent;

    return !acc.includes(receiversHash) ? [...acc, receiversHash] : acc;
  }, []);

  const beamsReceiverSeenEventsByReceiversHash = receiversHashes.reduce<{
    [receiversHash: string]: BeamsReceiverSeenEvent[];
  }>((acc, receiversHash) => {
    const receivers = deduplicateArray(
      sortedBeamsSetEvents
        .filter((event) => event.receiversHash === receiversHash)
        .reduce<BeamsReceiverSeenEvent[]>(
          (acc, event) => [...acc, ...event.beamsReceiverSeenEvents],
          [],
        ),
      'config',
    );

    return {
      ...acc,
      [receiversHash]: receivers,
    };
  }, {});

  return sortedBeamsSetEvents.reduce<BeamsSetEventWithFullReceivers[]>(
    (acc, beamsSetEvent) => [
      ...acc,
      {
        ...beamsSetEvent,
        currentReceivers: beamsReceiverSeenEventsByReceiversHash[beamsSetEvent.receiversHash] ?? [],
      },
    ],
    [],
  );
}

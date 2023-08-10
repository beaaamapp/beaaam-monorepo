import type { BeamsSetEvent, BeamsSetEventWithFullReceivers } from './types';

type ReceiversHash = string;

interface BeamsReceiverSeenEvent {
	id: string;
	receiverUserId: string;
	config: bigint;
}

export const sortBeamsSetEvents = <T extends BeamsSetEvent>(beamsSetEvents: T[]): T[] =>
	beamsSetEvents.sort((a, b) => Number(a.blockTimestamp) - Number(b.blockTimestamp));

export const deduplicateArray = <T>(array: T[], key: keyof T): T[] => [
	...new Map(array.map((item) => [item[key], item])).values()
];

export const reconcileBeamsSetReceivers = (beamsSetEvents: BeamsSetEvent[]): BeamsSetEventWithFullReceivers[] => {
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
				.reduce<BeamsReceiverSeenEvent[]>((accc, event) => [...accc, ...event.beamsReceiverSeenEvents], []),
			'config'
		);

		return {
			...acc,
			[receiversHash]: receivers
		};
	}, {});

	return sortedBeamsSetEvents.reduce<BeamsSetEventWithFullReceivers[]>(
		(acc, beamsSetEvent) => [
			...acc,
			{
				...beamsSetEvent,
				currentReceivers: beamsReceiverSeenEventsByReceiversHash[beamsSetEvent.receiversHash] ?? []
			}
		],
		[]
	);
};

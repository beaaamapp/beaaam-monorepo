import type { BeamsSetEvent } from 'beaaams-backend';

export default <T extends BeamsSetEvent>(beamsSetEvents: T[]): T[] =>
  beamsSetEvents.sort((a, b) => Number(a.blockTimestamp) - Number(b.blockTimestamp));

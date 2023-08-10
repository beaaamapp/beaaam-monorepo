import { Utils } from 'beaaams-backend';
import type { z } from 'zod';
import type { streamMetadataSchema } from '../metadata';

/**
 * Given a particular beamsReceiverSeenEvent, find matching metadata from an array of metadata
 * stream objects and return the first match.
 * @param receiverSeenEvent The on-chain receiverSeenEvent to find a matching metadata object for.
 * @param metadataStreams The stream metadata objects to match against the receiverSeenEvent.
 * @returns The matching streamMetadata object, or undefined if none.
 * @throw An error if multiple stream metadata objects match the given receiverSeenEvent, because
 * that should never happen.
 */
export default function matchMetadataStreamToReceiver(
  receiverSeenEvent: { receiverUserId: string; config: bigint },
  metadataStreams: z.infer<typeof streamMetadataSchema>[],
): z.infer<typeof streamMetadataSchema> | undefined {
  const results = metadataStreams.filter(
    (stream) =>
      stream.initialBeamsConfig.beamId ===
      Utils.BeamsReceiverConfiguration.fromUint256(receiverSeenEvent.config).beamId.toString(),
  );

  if (results.length > 1) {
    throw new Error('Metadata stream object somehow matches multiple on-chain receivers.');
  }

  return results[0];
}

import assert from '$lib/utils/assert';
import { isAddress } from 'ethers/lib/utils';

const numericTest = /^\d+$/;

/**
 * Create a globally unique Stream ID string, including the stream's sender user ID and the associated receiver's
 * beamId, as well as the token address.
 * @param senderUserId The stream sender's userId.
 * @param tokenAddress The token address of the currency the stream is in.
 * @param beamId The beamId of the stream's associated receiver.
 * @returns The stream ID string.
 */
export default function makeStreamId(senderUserId: string, tokenAddress: string, beamId: string) {
  if (!(numericTest.test(senderUserId) && numericTest.test(beamId) && isAddress(tokenAddress))) {
    throw new Error('Invalid values');
  }

  return `${senderUserId}-${tokenAddress}-${beamId}`;
}

/**
 * Given a stream ID created with `makeStreamId`, decode it into its three parts; the sender's user ID, the token
 * address and the beamId of the on-chain receiver.
 * @param streamId The stream ID to decode.
 * @returns An object including the stream's sender user ID, the token address of the token the stream is streaming,
 * and the on-chain beamId.
 */
export function decodeStreamId(streamId: string) {
  const parts = streamId.split('-');

  assert(parts.length === 3, 'Invalid stream ID');

  const values = {
    senderUserId: parts[0],
    tokenAddress: parts[1],
    beamId: parts[2],
  };

  if (
    !(
      numericTest.test(values.senderUserId) &&
      numericTest.test(values.beamId) &&
      isAddress(values.tokenAddress)
    )
  ) {
    throw new Error('Invalid stream ID');
  }

  return values;
}

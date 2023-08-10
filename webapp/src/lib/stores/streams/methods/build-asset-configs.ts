import { AddressDriverClient, constants, Utils } from 'beaaams-backend';
import type { z } from 'zod';
import type { accountMetadataSchema, assetConfigMetadataSchema } from '../metadata';
import type { AssetConfig, AssetConfigHistoryItem, BeamsConfig, Receiver, Stream } from '../types';
import makeStreamId from './make-stream-id';
import assert from '$lib/utils/assert';
import matchMetadataStreamToReceiver from './match-metadata-stream-to-receiver';
import type { BeamsSetEventWithFullReceivers } from './reconcile-beams-set-receivers';

function mapReceiverToStream(
  receiver: Receiver,
  senderUserId: string,
  tokenAddress: string,
  assetConfigMetadata?: z.infer<typeof assetConfigMetadataSchema>,
): Stream {
  const streamMetadata = assetConfigMetadata?.streams.find(
    (streamMetadata) => streamMetadata.id === receiver.streamId,
  );
  const initialBeamsConfig = streamMetadata?.initialBeamsConfig;

  const beamsConfig: BeamsConfig | undefined =
    receiver.beamsConfig ||
    (initialBeamsConfig && {
      beamId: initialBeamsConfig.beamId,
      raw: BigInt(initialBeamsConfig.raw),
      amountPerSecond: {
        amount: initialBeamsConfig.amountPerSecond,
        tokenAddress,
      },
      startDate:
        initialBeamsConfig.startTimestamp && initialBeamsConfig.startTimestamp > 0
          ? new Date(initialBeamsConfig.startTimestamp * 1000)
          : undefined,
      durationSeconds:
        initialBeamsConfig.durationSeconds !== 0 ? initialBeamsConfig.durationSeconds : undefined,
    });

  assert(
    beamsConfig,
    'Both stream metadata and on-chain data cannot have an undefined beamsConfig',
  );

  return {
    id: receiver.streamId,
    sender: {
      driver: 'address',
      userId: senderUserId,
      address: AddressDriverClient.getUserAddress(senderUserId),
    },
    receiver: receiver.receiver,
    beamsConfig,
    paused: !receiver.beamsConfig,
    managed: Boolean(streamMetadata),
    name: streamMetadata?.name,
    description: streamMetadata?.description,
    archived: streamMetadata?.archived ?? false,
  };
}

/**
 * Given accountMetadata and on-chain beamsSetEvents, construct an object describing
 * the account, including the full history of all its assetConfigs, with on-chain receivers
 * matched onto IPFS stream metadata.
 * @param userId The userId to build assetConfigs for.
 * @param accountMetadata The metadata for the given account fetched from IPFS.
 * @param beamsSetEvents The on-chain history of beamsSetEvents for the given account.
 * @returns The constructed Account object.
 * @throw An error if an assetConfig exists in metadata that no beamsSet events exist for.
 * @throw An error if any of the receivers existing onChain match multiple streams described
 * in metadata.
 */
export default function buildAssetConfigs(
  userId: string,
  accountMetadata: z.infer<typeof accountMetadataSchema> | undefined,
  beamsSetEvents: { [tokenAddress: string]: BeamsSetEventWithFullReceivers[] },
) {
  return Object.entries(beamsSetEvents).reduce<AssetConfig[]>(
    (acc, [tokenAddress, assetConfigBeamsSetEvents]) => {
      const assetConfigMetadata = accountMetadata?.assetConfigs.find(
        (ac) => ac.tokenAddress.toLowerCase() === tokenAddress.toLowerCase(),
      );

      assert(
        assetConfigBeamsSetEvents && assetConfigBeamsSetEvents.length > 0,
        `Unable to find beamsSet events for asset config with token address ${tokenAddress}`,
      );

      const assetConfigHistoryItems: AssetConfigHistoryItem[] = [];

      for (const beamsSetEvent of assetConfigBeamsSetEvents) {
        const assetConfigHistoryItemStreams: Receiver[] = [];

        const remainingStreamIds =
          assetConfigMetadata?.streams.map((stream) =>
            makeStreamId(userId, tokenAddress, stream.initialBeamsConfig.beamId),
          ) ?? [];

        for (const beamsReceiverSeenEvent of beamsSetEvent.currentReceivers) {
          const matchingStream = matchMetadataStreamToReceiver(
            beamsReceiverSeenEvent,
            assetConfigMetadata?.streams ?? [],
          );

          const eventConfig = Utils.BeamsReceiverConfiguration.fromUint256(
            beamsReceiverSeenEvent.config,
          );

          const streamId = makeStreamId(userId, tokenAddress, eventConfig.beamId.toString());

          assetConfigHistoryItemStreams.push({
            streamId,
            beamsConfig: {
              raw: beamsReceiverSeenEvent.config,
              startDate:
                eventConfig.start > 0n ? new Date(Number(eventConfig.start) * 1000) : undefined,
              amountPerSecond: {
                amount: eventConfig.amountPerSec,
                tokenAddress,
              },
              beamId: eventConfig.beamId.toString(),
              durationSeconds: eventConfig.duration > 0n ? Number(eventConfig.duration) : undefined,
            },
            managed: Boolean(matchingStream),
            receiver: {
              address: AddressDriverClient.getUserAddress(beamsReceiverSeenEvent.receiverUserId),
              driver: 'address',
              userId: String(beamsReceiverSeenEvent.receiverUserId),
            },
          });

          remainingStreamIds.splice(remainingStreamIds.indexOf(streamId), 1);
        }

        /*
        If a particular stream doesn't appear within beamsReceiverSeenEvents of a given
        beamsSet event, but did at least once before, we can assume it is paused.
        */
        for (const remainingStreamId of remainingStreamIds) {
          const stream = assetConfigMetadata?.streams.find(
            (stream) => stream.id === remainingStreamId,
          );
          if (!stream) break;

          const streamExistedBefore = assetConfigHistoryItems.find((item) =>
            item.streams.find((stream) => stream.streamId === remainingStreamId),
          );

          if (streamExistedBefore) {
            assetConfigHistoryItemStreams.push({
              streamId: remainingStreamId,
              // Undefined beamsConfig == stream was paused
              beamsConfig: undefined,
              managed: true,
              receiver: {
                ...stream.receiver,
                address: AddressDriverClient.getUserAddress(stream.receiver.userId),
              },
            });
          }
        }

        let runsOutOfFunds: Date | undefined;

        // If maxEnd is the largest possible timestamp, all current streams end before balance is depleted.
        if (beamsSetEvent.maxEnd === 2n ** 32n - 1n) {
          runsOutOfFunds = undefined;
        } else if (beamsSetEvent.maxEnd === 0n) {
          runsOutOfFunds = undefined;
        } else {
          runsOutOfFunds = new Date(Number(beamsSetEvent.maxEnd) * 1000);
        }

        assetConfigHistoryItems.push({
          timestamp: new Date(Number(beamsSetEvent.blockTimestamp) * 1000),
          balance: {
            tokenAddress: tokenAddress,
            amount: beamsSetEvent.balance * BigInt(constants.AMT_PER_SEC_MULTIPLIER),
          },
          runsOutOfFunds,
          streams: assetConfigHistoryItemStreams,
          historyHash: beamsSetEvent.beamsHistoryHash,
          receiversHash: beamsSetEvent.receiversHash,
        });
      }

      const currentStreams = assetConfigHistoryItems[assetConfigHistoryItems.length - 1].streams;

      acc.push({
        tokenAddress: tokenAddress,
        streams: currentStreams.map((receiver) =>
          mapReceiverToStream(receiver, userId, tokenAddress, assetConfigMetadata),
        ),
        history: assetConfigHistoryItems,
      });

      return acc;
    },
    [],
  );
}

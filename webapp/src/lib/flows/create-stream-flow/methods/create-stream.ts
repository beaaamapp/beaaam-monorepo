import type { StepComponentEvents } from '$lib/components/stepper/types';
import {
  getAddressDriverClient,
  getCallerClient,
  getNetworkConfig,
} from '$lib/utils/get-beams-clients';
import assert from '$lib/utils/assert';
import type { Account } from '$lib/stores/streams/types';
import type { TokenInfoWrapper } from '$lib/stores/tokens/tokens.store';
import { AddressDriverPresets, Utils } from 'beaaams-backend';
import { get } from 'svelte/store';
import wallet from '$lib/stores/wallet/wallet.store';
import makeStreamId, { decodeStreamId } from '$lib/stores/streams/methods/make-stream-id';
import {
  generateMetadata,
  pinAccountMetadata,
  USER_DATA_KEY,
  type streamMetadataSchema,
} from '$lib/stores/streams/metadata';
import type { z } from 'zod';
import expect from '$lib/utils/expect';
import streams from '$lib/stores/streams';
import mapFilterUndefined from '$lib/utils/map-filter-undefined';
import randomBigintUntilUnique from '$lib/utils/random-bigint-until-unique';
import transact, { makeTransactPayload } from '$lib/components/stepper/utils/transact';
import type { createEventDispatcher } from 'svelte';

export default function (
  dispatch: ReturnType<typeof createEventDispatcher<StepComponentEvents>>,
  selectedToken: TokenInfoWrapper,
  amountPerSecond: bigint,
  recipientAddress: string,
  streamName: string,
  ownAccount: Account,
  schedule?: {
    start: Date;
    end: Date;
  },
) {
  transact(
    dispatch,
    makeTransactPayload({
      before: async () => {
        const callerClient = await getCallerClient();
        const addressDriverClient = await getAddressDriverClient();
        const ownUserId = (await addressDriverClient.getUserId()).toString();

        const { address: tokenAddress } = selectedToken.info;

        const assetConfig = ownAccount.assetConfigs.find(
          (ac) => ac.tokenAddress.toLowerCase() === tokenAddress.toLowerCase(),
        );
        assert(assetConfig, "App hasn't yet fetched the right asset config");

        const currentReceivers = mapFilterUndefined(assetConfig.streams, (stream) =>
          stream.paused
            ? undefined
            : {
                userId: stream.receiver.userId,
                config: stream.beamsConfig.raw,
              },
        );

        const start = schedule ? BigInt(schedule.start.getTime() / 1000) : 0n;

        const duration = schedule
          ? BigInt(Math.floor((schedule.end.getTime() - schedule.start.getTime()) / 1000))
          : 0n;

        const beamId = randomBigintUntilUnique(
          assetConfig.streams.map((s) => BigInt(decodeStreamId(s.id).beamId)),
          4,
        );

        const beamConfig = Utils.BeamsReceiverConfiguration.toUint256({
          beamId,
          start,
          duration,
          amountPerSec: amountPerSecond,
        });

        const recipientUserId = await addressDriverClient.getUserIdByAddress(recipientAddress);
        const { address, signer } = get(wallet);
        assert(address);

        const newStreamMetadata: z.infer<typeof streamMetadataSchema> = {
          id: makeStreamId(ownUserId, tokenAddress, beamId.toString()),
          initialBeamsConfig: {
            beamId: beamId.toString(),
            raw: beamConfig.toString(),
            startTimestamp: Number(start),
            durationSeconds: Number(duration),
            amountPerSecond,
          },
          receiver: {
            userId: recipientUserId.toString(),
            driver: 'address',
          },
          archived: false,
          name: streamName,
        };

        const accountMetadata = generateMetadata(ownAccount, address);
        const currentAssetConfigIndex = accountMetadata.assetConfigs.findIndex(
          (ac) => ac.tokenAddress.toLowerCase() === tokenAddress.toLowerCase(),
        );

        if (currentAssetConfigIndex === -1) {
          accountMetadata.assetConfigs.push({
            tokenAddress,
            streams: [newStreamMetadata],
          });
        } else {
          const current = accountMetadata.assetConfigs[currentAssetConfigIndex];
          accountMetadata.assetConfigs[currentAssetConfigIndex] = {
            ...current,
            streams: [...current.streams, newStreamMetadata],
          };
        }

        const newHash = await pinAccountMetadata(accountMetadata);

        const { ADDRESS_DRIVER } = getNetworkConfig();

        const createStreamBatchPreset = await AddressDriverPresets.Presets.createNewStreamFlow({
          signer,
          driverAddress: ADDRESS_DRIVER,
          tokenAddress,
          currentReceivers,
          newReceivers: [
            ...currentReceivers,
            {
              config: beamConfig,
              userId: recipientUserId,
            },
          ],
          userMetadata: [
            {
              key: USER_DATA_KEY,
              value: newHash,
            },
          ],
          balanceDelta: 0,
          transferToAddress: address,
        });

        return {
          createStreamBatchPreset,
          callerClient,
          ownUserId,
          newHash,
        };
      },

      transactions: (transactContext) => ({
        transaction: () =>
          transactContext.callerClient.callBatched(transactContext.createStreamBatchPreset),
      }),

      after: async (_, transactContext) => {
        /*
      We wait up to five seconds for `refreshUserAccount` to update the user's own
      account's `lastIpfsHash` to the new hash we just published.
      */
        await expect(
          streams.refreshUserAccount,
          () =>
            get(streams).accounts[transactContext.ownUserId].lastIpfsHash ===
            transactContext.newHash,
          5000,
          1000,
        );
      },
    }),
  );
}

import ens from '$lib/stores/ens';
import { getAddressDriverClient } from '$lib/utils/get-beams-clients';
import { isAddress } from 'ethers/lib/utils';
import { AddressDriverClient } from 'beaaams-backend';

export default async function (userId: string): Promise<{
  address: string;
  beamsUserId: string;
}> {
  if (isAddress(userId)) {
    const address = userId;
    const beamsUserId = await (await getAddressDriverClient()).getUserIdByAddress(userId);

    return {
      address,
      beamsUserId,
    };
  } else if (/^\d+$/.test(userId)) {
    // User ID param has only numbers and is probably a beams user ID
    const beamsUserId = userId;
    const address = AddressDriverClient.getUserAddress(userId);

    return {
      address,
      beamsUserId,
    };
  } else if (userId.endsWith('.eth')) {
    const lookup = await ens.reverseLookup(userId);
    if (lookup) {
      const beamsUserId = await (await getAddressDriverClient()).getUserIdByAddress(lookup);
      const address = lookup;

      return {
        address,
        beamsUserId,
      };
    } else {
      throw new Error('Not found');
    }
  } else {
    throw new Error('Not found.');
  }
}

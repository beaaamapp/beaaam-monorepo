// import { PINATA_SDK_KEY, PINATA_SDK_SECRET } from '$env/static/private';

import pinataSdk from '@pinata/sdk';
import { error, type RequestEvent, type RequestHandler } from '@sveltejs/kit';
import { accountMetadataSchema } from '$lib/stores/streams/metadata';

const PINATA_SDK_KEY = '0f787903bc8804d67407'
const PINATA_SDK_SECRET = '61674ba4a6c0bba4923f3b28d4c65bcabbead0e362b797705568850f5c0038a8'
const pinata = pinataSdk(PINATA_SDK_KEY, PINATA_SDK_SECRET);

export const POST: RequestHandler = async ({ request }: RequestEvent) => {
  try {
    const json = await request.json();

    accountMetadataSchema.parse(json);

    const res = await pinata.pinJSONToIPFS(json, {
      pinataOptions: {
        cidVersion: 0,
      },
    });

    return new Response(res.IpfsHash);
  } catch (e) {
    throw error(500, "This doesn't seem to be valid account metadata 🤨");
  }
};

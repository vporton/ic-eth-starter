import { Signer } from 'ethers';

export async function scoreSignature(signer: Signer): Promise<{address: string, signature: string}> {
  const address = await signer.getAddress()
  const message = "I certify that I am the owner of the Ethereum account\n" + address;
  const signature = await signer.signMessage(message);
  return {address, signature};
}
import { Signer } from 'ethers';

function buf2hex(buffer: Uint8Array) { // buffer is an ArrayBuffer
  return Array.from(buffer)
      .map(x => x.toString(16).padStart(2, '0'))
      .join('');
}

export async function scoreSignature(signer: Signer): Promise<{address: string, signature: string, nonce: string}> {
  const address = await signer.getAddress();
  const nonceBuf = new Uint8Array(20); // the same security as an Ethereum address
  crypto.getRandomValues(nonceBuf);
  const nonce = buf2hex(nonceBuf);
  const message = "I am the owner of the Ethereum account\n" + address +
    "\n\nwhich I certify by providing a random value:\n" + nonce;
  const signature = await signer.signMessage(message);
  return {address, signature, nonce};
}
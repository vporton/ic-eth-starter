import { Signer } from 'ethers';

async function myScore(signer: Signer): number {
  const address = await signer.getAddress()
  const message = "I certify that I am the owner of the Etheretum account\n" + address;
  const signature = signer.signMessage(message);
  
  backend.scoreBySignedEthereumAddress(address, signature);
)
}
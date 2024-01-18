import React, { useEffect, useState } from 'react';
import Container from 'react-bootstrap/Container';
import Row from 'react-bootstrap/Row';
import Button from 'react-bootstrap/Button';
// import Onboard from '@web3-onboard/core'
import { init, useConnectWallet } from '@web3-onboard/react'
import walletConnectModule, {
  // WalletConnectOptions,
} from "@web3-onboard/walletconnect";
import injectedModule from '@web3-onboard/injected-wallets'
import { ethers } from 'ethers'
import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';
import { scoreSignature } from 'passport_client_dfinity-client';
import { createActor as createBackendActor } from './declarations/backend'
import config from './config.json';
import ourCanisters from './our-canisters.json';
import { HttpAgent } from '@dfinity/agent';

const walletConnectOptions/*: WalletConnectOptions*/ = {
  projectId:
    (config.WALLET_CONNECT_PROJECT_ID as string) ||
    "default-project-id",
  dappUrl: "http://localhost:3000/", // TODO
};
 
const blockNativeApiKey = config.BLOCKNATIVE_KEY as string;

const onBoardExploreUrl =
  (config.BLOCKNATIVE_KEY as string) ||
  "http://localhost:3000/"; // TODO

const walletConnect = walletConnectModule(walletConnectOptions);
const injected = injectedModule()
const wallets = [injected, walletConnect]

const chains = [
  {
    id: 1,
    token: 'ETH',
    label: 'Ethereum Mainnet',
    rpcUrl: `https://mainnet.infura.io/v3/${config.INFURA_ID}`, // FIXME
  },
];

const appMetadata = {
  name: 'Example Identity App',
  icon: '/logo.svg',
  logo: '/logo.svg',
  description: 'Example app providing personhood on DFINITY Internet Computer',
  explore: onBoardExploreUrl,
  recommendedInjectedWallets: [
    { name: 'Coinbase', url: 'https://wallet.coinbase.com/' },
    { name: 'MetaMask', url: 'https://metamask.io' }
  ],
};

const accountCenter = {
  desktop: {
    enabled: true,
  },
  mobile: {
    enabled: true,
    minimal: true,
  },
};

// const onboard = Onboard({
//   wallets,
//   chains,
//   appMetadata
// })

const onboard = init({
  appMetadata,
  apiKey: blockNativeApiKey,
  wallets,
  chains,
  accountCenter,
});

// UI actions:
// - connect: ask for signature, store the signature, try to retrieve, show retrieval status
// - recalculate: recalculate, show retrieval status
function App() {
  const agent = new HttpAgent({});
  if (config.IS_LOCAL) {
    agent.fetchRootKey();
  }

  const [signature, setSignature] = useState<string>();
  const [address, setAddress] = useState<string>();
  const [score, setScore] = useState<number | 'didnt-read' | 'retrieved-none'>('didnt-read');

  const [{ wallet, connecting }, connect, disconnect] = useConnectWallet();

  useEffect(() => {
    if (!wallet) {
      setAddress(undefined);
      setSignature(undefined);
    }
  }, [wallet]);

  async function obtainScore() {
    const ethersProvider = new ethers.BrowserProvider(wallet!.provider, 'any');
    const signer = await ethersProvider.getSigner();
    const { address, signature } = await scoreSignature(signer);
    setAddress(address);
    setSignature(signature);
    const backend = createBackendActor(ourCanisters.BACKEND_CANISTER_ID, {agent});
    try {
      const result = await backend.scoreBySignedEthereumAddress({address, signature});
      const j = JSON.parse(result);
      let score = j.score;
      setScore(/^\d+(\.\d+)/.test(score) ? score : 'retrieved-none');
    }
    catch(_) {
      setScore('retrieved-none');
    }
  }

  // TODO: Enable button only when all variables are true.
  async function recalculateScore() {
    const backend = createBackendActor(ourCanisters.BACKEND_CANISTER_ID, {agent}); // TODO: duplicate code
    try {
      const result = await backend.submitSignedEthereumAddressForScore({address: address!, signature: signature!});
      const j = JSON.parse(result);
      let score = j.score;
      setScore(/^\d+(\.\d+)?/.test(score) ? score : 'retrieved-none');
    }
    catch(_) {
      setScore('retrieved-none');
    }
}

  return (
    <div className="App">
      <Container>
        <Row>
          <h1>Example Identity App</h1>
          <p>This is an example app for DFINITY Internet Computer, that connects to{' '}
            <a target='_blank' href="https://passport.gitcoin.co" rel="noreferrer">Gitcoin Passport</a>{' '}
            to prove user's personhood and uniqueness (for example, against so called <q>Sybil attack</q>, that is when
            a user votes more than once).</p>
          <p>The current version of this app requires use of an Ethereum wallet that you need
            both in Gitcoin Passport and in this app. (So, in real Internet Computer apps
            you will need two wallets: DFINITY Internet Computer wallet and Ethereum wallet.){' '}
            You don't need to have any funds on your wallet to use this app (because you will use an Ethereum wallet{' '}
            only to sign a message for this app, not for any transactions).
            In the future <a target='_blank' href="https://portonvictor.org" rel="noreferrer">I</a> am going to
            add DFINITY Internet Computer support to Gitcoin Passport, to avoid the need to create an Ethereum wallet
            to verify personhood in apps like this.</p>
          <h2>Steps</h2>
          <ol>
            <li>Go to <a target='_blank' href="https://passport.gitcoin.co" rel="noreferrer">Gitcoin Passport</a>{' '}
              and prove your personhood.</li>
            <li>Return to this app and<br/>
              <Button disabled={connecting} onClick={() => (wallet ? disconnect(wallet) : connect())}>
                {connecting ? 'connecting' : wallet ? 'Disconnect Ethereum' : 'Connect Ethereum'}
              </Button>{' '}
              with the same wallet, as one you used for Gitcoin Password.<br/>
              Your wallet: {address ? `<small>${address}</small>` : 'not connected'}.
            </li>
            <li>Check the score<br/>
              <Button disabled={!agent || !wallet} onClick={obtainScore}>Get you identity score</Button>
            </li>
            <li>If needed,<br/>
              <Button disabled={!address || !signature || !agent || !wallet} onClick={recalculateScore}>
                Recalculate your identity score
              </Button>
            </li>
          </ol>
          <p>Your identity score:{' '}
            {score === 'didnt-read' ? 'Click the above button to check.'
              : score === 'retrieved-none' ? 'Not yet calculated'
              : `${score} ${typeof score == 'number' && score >= 20
              ? '(Congratulations: You\'ve been verified.)'
              : '(Sorry: It\'s <20, you are considered a bot.)'}`}
          </p>
        </Row>
      </Container>
    </div>
  );
}

export default App;

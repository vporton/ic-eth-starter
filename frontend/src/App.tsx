import React, { useEffect, useMemo, useState } from 'react';
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
import { createActor as createBackendActor } from './declarations/backend';
import { createActor as createCanDBPartitionActor } from './declarations/CanDBPartition';
import config from './config.json';
import ourCanisters from './our-canisters.json';
import { HttpAgent } from '@dfinity/agent';
import { ClipLoader } from 'react-spinners';
import { Principal } from '@dfinity/candid/lib/cjs/idl';

const walletConnectOptions/*: WalletConnectOptions*/ = {
  projectId:
    (config.WALLET_CONNECT_PROJECT_ID as string) ||
    "default-project-id",
  dappUrl: config.DAPP_URL,
};
 
const blockNativeApiKey = config.BLOCKNATIVE_KEY as string;

const onBoardExploreUrl = undefined;

const walletConnect = walletConnectModule(walletConnectOptions);
const injected = injectedModule()
const wallets = [injected, walletConnect]

const chains = [
  {
    id: 1,
    token: 'ETH',
    label: 'Ethereum Mainnet',
    rpcUrl: config.MAINNET_RPC,
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
  const agent = useMemo(() => {
    const agent = new HttpAgent({});
    if (config.IS_LOCAL) {
      agent.fetchRootKey();
    }
    return agent;
  }, []);

  const [signature, setSignature] = useState<string>();
  const [message, setMessage] = useState<string>();
  const [nonce, setNonce] = useState<string>();
  const [address, setAddress] = useState<string>();
  const [score, setScore] = useState<number | 'didnt-read' | 'retrieved-none'>('didnt-read');
  const [obtainScoreLoading, setObtainScoreLoading] = useState(false);
  const [recalculateScoreLoading, setRecalculateScoreLoading] = useState(false);
  const [principal, setPrincipal] = useState<string | undefined>();

  const [{ wallet, connecting }, connect, disconnect] = useConnectWallet();

  useEffect(() => {
    const storagePrincipal = localStorage.getItem('person:storagePrincipal');
    const part = createCanDBPartitionActor(storagePrincipal, {agent}); // TODO: duplicate code
    const user = part.getUser(principal);
    setScore(user.personhoodScore);
  });

  useEffect(() => {
      if (wallet) {
      const ethersProvider = new ethers.BrowserProvider(wallet!.provider, 'any'); // TODO: duplicate code
      // This does not work:
      // ethersProvider.on('accountsChanged', function (accounts) {
      //   setAddress(accounts[0]);
      // });
      ethersProvider.send('eth_requestAccounts', []).then((accounts) => {
        setAddress(accounts[0]);
      });
    } else {
      setAddress(undefined);
    }
  }, [wallet]);

  async function storePerson({ personIdPrincipal, personStoragePrincipal, score }) {
    // Scorer returns 0E-9 for zero.
    setScore(/^\d+(\.\d+)?$|^0E-9$/.test(score.toString()) ? Number(score) : 'retrieved-none');
    localStorage.setItem('person:storagePrincipal', personStoragePrincipal);
  }

  async function obtainScore() {
    try {
      try {
        setObtainScoreLoading(true);
        let localMessage = message;
        let localNonce = nonce;
        const backend = createBackendActor(ourCanisters.CANISTER_ID_BACKEND, {agent}); // TODO: duplicate code
        if (nonce === undefined) {
          const {message, nonce} = await backend.getEthereumSigningMessage();
          localMessage = message;
          localNonce = nonce;
          setMessage(localMessage);
          setNonce(localNonce);
        }
        let localSignature = signature;
        if (signature === undefined) {
          const ethersProvider = new ethers.BrowserProvider(wallet!.provider, 'any'); // TODO: duplicate code
          const signer = await ethersProvider.getSigner();
          let signature = await signer.signMessage(localMessage!);
          localSignature = signature;
          setSignature(localSignature);
        }
        const res = await backend.scoreBySignedEthereumAddress({
          address: address!, signature: localSignature!, nonce: localNonce!, oldHint: [],
        });
        storePerson(res);
      }
      catch(e) {
        console.log(e);
        setScore('retrieved-none');
        alert(e);
      }
    }
    finally {
      setObtainScoreLoading(false);
    }
  }

  async function recalculateScore() {
    try {
      setRecalculateScoreLoading(true);
      const backend = createBackendActor(ourCanisters.CANISTER_ID_BACKEND, {agent}); // TODO: duplicate code
      try {
        const res = await backend.submitSignedEthereumAddressForScore({
          address: address!, signature: signature!, nonce: nonce!, oldHint: [],
        });
        storePerson(res);
      }
      catch(e) {
        setScore('retrieved-none');
        alert(e);
      }
    }
    finally {
      setRecalculateScoreLoading(false);
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
              Your wallet: {address ? <small>{address}</small> : 'not connected'}.
            </li>
            <li>Check the score<br/>
              <Button disabled={!agent || !wallet} onClick={obtainScore}>Get you identity score</Button>
              <ClipLoader loading={obtainScoreLoading}/>{' '}
            </li>
            <li>If needed,<br/>
              <Button disabled={!address || !signature || !agent || !wallet || !nonce} onClick={recalculateScore}>
                Recalculate your identity score
              </Button>
              <ClipLoader loading={recalculateScoreLoading}/>{' '}
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

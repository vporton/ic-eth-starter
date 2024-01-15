import React, { useState } from 'react';
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

const walletConnectOptions/*: WalletConnectOptions*/ = {
  projectId:
    (process.env.REACT_APP_WALLET_CONNECT_PROJECT_ID as string) ||
    "default-project-id",
  dappUrl: "http://localhost:3000/", // TODO
};
 
const blockNativeApiKey = process.env.REACT_APP_BLOCKNATIVE_KEY as string;

const onBoardExploreUrl =
  (process.env.REACT_APP_BLOCKNATIVE_KEY as string) ||
  "http://localhost:3000/"; // TODO

const walletConnect = walletConnectModule(walletConnectOptions);
const injected = injectedModule()
const wallets = [injected, walletConnect]

const chains = [
  {
    id: 1,
    token: 'ETH',
    label: 'Ethereum Mainnet',
    rpcUrl: 'https://mainnet.infura.io/v3/${INFURA_ID}', // FIXME
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

function App() {
  const [score, setScore] = useState<number | undefined>();

  const [{ wallet, connecting }, connect, disconnect] = useConnectWallet()

  // create an ethers provider
  let ethersProvider

  if (wallet) {
    // if using ethers v6 this is:
    ethersProvider = new ethers.BrowserProvider(wallet.provider, 'any')
    // ethersProvider = new ethers.providers.Web3Provider(wallet.provider, 'any')
  }
  
  return (
    <div className="App">
      <Container>
        <Row>
          <h1>Example Identity App</h1>
          <Button disabled={connecting} onClick={() => (wallet ? disconnect(wallet) : connect())}>
            {connecting ? 'connecting' : wallet ? 'Disconnect Ethereum' : 'Connect Ethereum'}
          </Button>
          <p>This is an example app for DFINITY Internet Computer, that connects to{' '}
            <a target='_blank' href="https://passport.gitcoin.co" rel="noreferrer">Gitcoin Passport</a>{' '}
            to prove user's personhood (against so called <q>Sybil attack</q>, that is when
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
            <li>Return to this app and check that it works with the same Ethereum wallet:<br/>
              <Button>Check your identity score</Button>
            </li>
          </ol>
          <p>Your identity score:{' '}
            {score === undefined ? 'Click the above button to check.'
              : `${score} ${score >= 20 ? '(Congratulations: You\'ve been verified.)'
                : '(Sorry: It\'s <20, you are considered a bot.)'}`}
          </p>
        </Row>
      </Container>
    </div>
  );
}

export default App;

import React, { useState } from 'react';
import Container from 'react-bootstrap/Container';
import Row from 'react-bootstrap/Row';
import Button from 'react-bootstrap/Button';
// import Onboard from '@web3-onboard/core'
import { init, useConnectWallet } from '@web3-onboard/react'
import injectedModule from '@web3-onboard/injected-wallets'
import { ethers } from 'ethers'
import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';

const apiKey = '1730eff0-9d50-4382-a3fe-89f0d34a2070'; // FIXME

const injected = injectedModule()
const wallets = [injected]

const infuraKey = '<INFURA_KEY>'; // FIXME;
const rpcUrl = `https://mainnet.infura.io/v3/${infuraKey}`;


const chains = [
  {
    id: 1,
    token: 'ETH',
    label: 'Ethereum Mainnet',
    rpcUrl: 'https://mainnet.infura.io/v3/${INFURA_ID}'
  },
];

const appMetadata = {
  name: 'Example Identity App',
  icon: '/public/logo.svg',
  logo: '/public/logo.svg',
  description: 'Example app providing personhood on DFINITY Internet Computer',
  recommendedInjectedWallets: [
    { name: 'Coinbase', url: 'https://wallet.coinbase.com/' },
    { name: 'MetaMask', url: 'https://metamask.io' }
  ],
};

// const onboard = Onboard({
//   wallets,
//   chains,
//   appMetadata
// })

init({
  apiKey,
  wallets: [injected],
  chains: [
    {
      id: '0x1',
      token: 'ETH',
      label: 'Ethereum Mainnet',
      rpcUrl
    },
    {
      id: 42161,
      token: 'ARB-ETH',
      label: 'Arbitrum One',
      rpcUrl: 'https://rpc.ankr.com/arbitrum'
    },
    {
      id: '0xa4ba',
      token: 'ARB',
      label: 'Arbitrum Nova',
      rpcUrl: 'https://nova.arbitrum.io/rpc'
    },
    {
      id: '0x2105',
      token: 'ETH',
      label: 'Base',
      rpcUrl: 'https://mainnet.base.org'
    }
  ]
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
          <button disabled={connecting} onClick={() => (wallet ? disconnect(wallet) : connect())}>
            {connecting ? 'connecting' : wallet ? 'disconnect' : 'connect'}
          </button>
          <p>This is an example app for DFINITY Internet Computer, that connects to{' '}
            <a target='_blank' href="https://passport.gitcoin.co/" rel="noreferrer">Gitcoin Passport</a>{' '}
            to prove user's personhood (against so called <q>Sybil attack</q>, that is when
            a user votes more than once).</p>
          <p>The current version of this app requires use of an Ethereum wallet (So, in real Internet Computer apps
            you will need two wallets: DFINITY Internet Computer wallet and Ethereum wallet.) that you need
            both in Gitcoin Passport and in this app.{' '}
            In the future <a target='_blank' href="https://portonvictor.org" rel="noreferrer">I</a> am going to
            add DFINITY Internet Computer support to Gitcoin Passport, to avoid the need to create an Ethereum wallet
            to verify personhood in apps like this.</p>
          <h2>Steps</h2>
          <ol>
            <li>Go to <a target='_blank' href="https://passport.gitcoin.co/" rel="noreferrer">Gitcoin Passport</a>{' '}
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

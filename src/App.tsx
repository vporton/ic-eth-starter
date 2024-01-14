import React, { useState } from 'react';
import Container from 'react-bootstrap/Container';
import Row from 'react-bootstrap/Row';
import Button from 'react-bootstrap/Button';
import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';

function App() {
  const [score, setScore] = useState<number | undefined>();

  return (
    <div className="App">
      <Container>
        <Row>
          <h1>Example Identity App</h1>
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
                : '(Sorry: it\'s <20, you are considered a bot.)'}`}
          </p>
        </Row>
      </Container>
    </div>
  );
}

export default App;

# DFINITY ICP Gitcoin Passport Client

This is an example app for DFINITY Internet Computer, that connects to [Gitcoin Passport](https://passport.gitcoin.co/) to prove user's personhood and uniqueness (for example, against so called "Sybil attack", that is when a user votes more than once).

The current version of this app requires use of an Ethereum wallet that you need both in Gitcoin Passport and in this app. (So, in real Internet Computer apps you will need two wallets: DFINITY Internet Computer wallet and Ethereum wallet.) You don't need to have any funds on your wallet to use this app (because you will use an Ethereum wallet only to sign a message for this app, not for any transactions). In the future [I](https://portonvictor.org) am going to add DFINITY Internet Computer support to Gitcoin Passport, to avoid the need to create an Ethereum wallet to verify personhood in apps like this.

## Testing

Copy `X.example.Y` files to `X.Y` and edit them.

```
make
```

Running the app with `npm start` currently does not work as intended due to a bug.
But you can open the URL of `frontend` printed by `dfx deploy frontend` to test the app on localhost.
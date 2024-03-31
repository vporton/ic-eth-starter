import Types "../lib/Types";
import V "../lib/Verifier";
import Config "../../Config";
import ic_eth "canister:ic_eth";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import CanDBIndex "canister:CanDBIndex";

actor {
    /// Called upon receipt of personhood from Gitcoin, to store personhood information in the CanDB DB.
    func processPersonhood({
        body: Text;
        /// The principal of the person.
        personPrincipal: Principal;
        /// The hint principal of the canister where to store `User` (identified by `personPrincipal`).
        personStoragePrincipal: ?Principal;
        /// The hint principal pf the canister where to store mapping from `ethereumAddress` to person principal.
        personIdStoragePrincipal: ?Principal;
        /// The Ethereum address of the user.
        ethereumAddress: Text;
    })
        : async* {
            /// Retrieved identity score.
            score: Float;
            /// Time at which the identity score was set at.
            time: Time.Time;
            /// The (possibly changed) canister where mapping from the Ethereum address to the principal will be stored (under `ethereumAddress` as the SK).
            personIdStoragePrincipal: Principal;
            /// The (possibly changed) canister where `User` data will be stored (under `personPrincipal` as the SK).
            personStoragePrincipal: Principal;
        }
    {
        // Extract Gitcoin personhood score and score time.
        let score = V.extractItemScoreFromBody(body);
        let time = V.extractDateFromBody(body);
        // Store personhood data in an anti-Sybil DB:
        let { personIdStoragePrincipal = idPrincipalNew; personStoragePrincipal = principalNew } =
            await CanDBIndex.storePersonhood({pk = "user"; personPrincipal; personStoragePrincipal; personIdStoragePrincipal; score; time; ethereumAddress});
        { score; time; personIdStoragePrincipal = idPrincipalNew; personStoragePrincipal = principalNew };
    };

    public shared({caller}) func scoreBySignedEthereumAddress({
        address: Text;
        signature: Text;
        nonce: Text;
        personStoragePrincipal: ?Principal;
        personIdStoragePrincipal: ?Principal;
    }): async {
        personIdStoragePrincipal: Principal;
        personStoragePrincipal: Principal;
        score: Float;
        time: Time.Time;
    } {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        // Use `extractItemScoreFromBody` or `extractItemScoreFromJSON` to extract score.
        let body = await* V.scoreBySignedEthereumAddress({
            ic_eth;
            address;
            signature;
            nonce;
            transform = removeHTTPHeaders;
            config = Config.config;
        });
        await* processPersonhood({body; personPrincipal = caller; personStoragePrincipal; personIdStoragePrincipal; ethereumAddress = address});
    };

    public shared({caller}) func submitSignedEthereumAddressForScore({
        address: Text;
        signature: Text;
        nonce: Text;
        personStoragePrincipal: ?Principal;
        personIdStoragePrincipal: ?Principal;
    }): async {
        personIdStoragePrincipal: Principal;
        personStoragePrincipal: Principal;
        score: Float;
        time: Time.Time;
    } {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        // Use `extractItemScoreFromBody` or `extractItemScoreFromJSON` to extract score.
        let body = await* V.submitSignedEthereumAddressForScore({
            ic_eth;
            address;
            signature;
            nonce;
            transform = removeHTTPHeaders;
            config = Config.config;
        });
        await* processPersonhood({body; personPrincipal = caller; personStoragePrincipal; personIdStoragePrincipal; ethereumAddress = address});
    };

    public shared func getEthereumSigningMessage(): async {message: Text; nonce: Text} {
        await* V.getEthereumSigningMessage({transform = removeHTTPHeaders; config = Config.config});
    };

    public shared query func removeHTTPHeaders(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.removeHTTPHeaders(args);
    };
}
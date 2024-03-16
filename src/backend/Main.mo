import Types "../lib/Types";
import V "../lib/Verifier";
import DB "../lib/DB";
import Config "../../Config";
import ic_eth "canister:ic_eth";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import E "mo:candb/Entity";
import CanDBIndex "canister:CanDBIndex";

actor {
    /// Called upon receipt of personhood from Gitcoin.
    func processPersonhood(body: Text, hint: ?Principal, ethereumAddress: Text)
        : async* { score: Float; personIdPrincipal: Principal; personPrincipal: Principal }
    {
        let score = V.extractItemScoreFromBody(body);
        let { personIdPrincipal; personPrincipal } = await CanDBIndex.storePersonhood(hint, score, ethereumAddress);
        { score; personIdPrincipal; personPrincipal };
    };

    public shared({caller}) func scoreBySignedEthereumAddress({address: Text; signature: Text; nonce: Text; oldHint: ?Principal}): async {
        personIdPrincipal: Principal;
        personPrincipal: Principal;
        score: Float
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
        await* processPersonhood(oldHint, address);
    };

    public shared({caller}) func submitSignedEthereumAddressForScore({address: Text; signature: Text; nonce: Text}): async {
        personIdPrincipal: Principal;
        personPrincipal: Principal;
        score : Float
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
        await* processPersonhood(body, caller);
    };

    public shared func getEthereumSigningMessage(): async {message: Text; nonce: Text} {
        await* V.getEthereumSigningMessage({transform = removeHTTPHeaders; config = Config.config});
    };

    public shared query func removeHTTPHeaders(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.removeHTTPHeaders(args);
    };
}
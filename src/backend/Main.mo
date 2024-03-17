import Types "../lib/Types";
import V "../lib/Verifier";
import Config "../../Config";
import ic_eth "canister:ic_eth";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import CanDBIndex "canister:CanDBIndex";

actor {
    /// Called upon receipt of personhood from Gitcoin.
    func processPersonhood({
        body: Text;
        personPrincipal: Principal;
        personStoragePrincipal: ?Principal;
        personIdStoragePrincipal: ?Principal;
        ethereumAddress: Text;
    })
        : async* { score: Float; time: Time.Time; personIdStoragePrincipal: Principal; personStoragePrincipal: Principal }
    {
        let score = V.extractItemScoreFromBody(body);
        let time = V.extractDateFromBody(body);
        let { personIdStoragePrincipal = idPrincipalNew; personStoragePrincipal = principalNew } =
            await CanDBIndex.storePersonhood({personPrincipal; personStoragePrincipal; personIdStoragePrincipal; score; time; ethereumAddress});
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
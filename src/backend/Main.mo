import Types "../lib/Types";
import V "../lib/Verifier";
import Config "../../Config";

actor Main {
    public shared func scoreBySignedEthereumAddress({address: Text; signature: Text; nonce: Text}): async Text {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        // Use `extractItemScoreFromBody` or `extractItemScoreFromJSON` to extract score.
        await* V.scoreBySignedEthereumAddress({
            address;
            signature;
            nonce;
            transform = removeHTTPHeaders;
            config = Config.config;
        });
    };

    public shared func submitSignedEthereumAddressForScore({address: Text; signature: Text; nonce: Text}): async Text {
        // A real app would store the verified address somewhere instead of just returning the score to frontend.
        // Use `extractItemScoreFromBody` or `extractItemScoreFromJSON` to extract score.
        await* V.submitSignedEthereumAddressForScore({
            address;
            signature;
            nonce;
            transform = removeHTTPHeaders;
            config = Config.config;
        });
    };

    public shared func getEthereumSigningMessage(): async {message: Text; nonce: Text} {
        await* V.getEthereumSigningMessage({transform = removeHTTPHeaders; config = Config.config});
    };

    public shared query func removeHTTPHeaders(args: Types.TransformArgs): async Types.HttpResponsePayload {
        V.removeHTTPHeaders(args);
    };
}